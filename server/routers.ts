import { COOKIE_NAME } from "@shared/const";
import { z } from "zod";
import { getSessionCookieOptions } from "./_core/cookies";
import { systemRouter } from "./_core/systemRouter";
import { protectedProcedure, publicProcedure, router } from "./_core/trpc";
import * as db from "./db";
import { invokeLLM } from "./_core/llm";
import { generateImage } from "./_core/imageGeneration";
import { transcribeAudio } from "./_core/voiceTranscription";
import { storagePut } from "./storage";

export const appRouter = router({
  system: systemRouter,

  auth: router({
    me: publicProcedure.query(opts => opts.ctx.user),
    logout: publicProcedure.mutation(({ ctx }) => {
      const cookieOptions = getSessionCookieOptions(ctx.req);
      ctx.res.clearCookie(COOKIE_NAME, { ...cookieOptions, maxAge: -1 });
      return {
        success: true,
      } as const;
    }),
  }),

  chat: router({
    createConversation: protectedProcedure
      .input(z.object({ title: z.string() }))
      .mutation(async ({ ctx, input }) => {
        const conversationId = await db.createConversation({
          userId: ctx.user.id,
          title: input.title,
        });
        return { id: conversationId };
      }),

    getConversations: protectedProcedure.query(async ({ ctx }) => {
      return db.getUserConversations(ctx.user.id);
    }),

    getMessages: protectedProcedure
      .input(z.object({ conversationId: z.number() }))
      .query(async ({ input }) => {
        return db.getConversationMessages(input.conversationId);
      }),

    sendMessage: protectedProcedure
      .input(z.object({
        conversationId: z.number(),
        content: z.string(),
      }))
      .mutation(async ({ ctx, input }) => {
        await db.createMessage({
          conversationId: input.conversationId,
          role: "user",
          content: input.content,
        });

        const messages = await db.getConversationMessages(input.conversationId);
        
        const llmMessages = messages.map(msg => ({
          role: msg.role as "user" | "assistant" | "system",
          content: msg.content,
        }));

        const response = await invokeLLM({
          messages: llmMessages,
        });

        const content = response.choices[0]?.message?.content;
        const assistantMessage = typeof content === 'string' ? content : "抱歉,我无法回答这个问题。";

        await db.createMessage({
          conversationId: input.conversationId,
          role: "assistant",
          content: assistantMessage,
        });

        return { content: assistantMessage };
      }),

    deleteConversation: protectedProcedure
      .input(z.object({ id: z.number() }))
      .mutation(async ({ input }) => {
        await db.deleteConversation(input.id);
        return { success: true };
      }),
  }),

  generate: router({
    text: protectedProcedure
      .input(z.object({ prompt: z.string() }))
      .mutation(async ({ ctx, input }) => {
        const response = await invokeLLM({
          messages: [
            { role: "system", content: "你是一个专业的内容创作助手,根据用户的要求生成高质量的文本内容。" },
            { role: "user", content: input.prompt },
          ],
        });

        const content = response.choices[0]?.message?.content;
        const result = typeof content === 'string' ? content : "生成失败";

        await db.createGeneratedContent({
          userId: ctx.user.id,
          type: "text",
          prompt: input.prompt,
          result,
        });

        return { result };
      }),

    image: protectedProcedure
      .input(z.object({ prompt: z.string() }))
      .mutation(async ({ ctx, input }) => {
        const imageResult = await generateImage({
          prompt: input.prompt,
        });
        
        const url = imageResult.url || "";

        await db.createGeneratedContent({
          userId: ctx.user.id,
          type: "image",
          prompt: input.prompt,
          result: url,
        });

        return { url };
      }),

    getHistory: protectedProcedure
      .input(z.object({ type: z.enum(["text", "image"]).optional() }))
      .query(async ({ ctx, input }) => {
        return db.getUserGeneratedContent(ctx.user.id, input.type);
      }),
  }),

  transcription: router({
    create: protectedProcedure
      .input(z.object({
        audioUrl: z.string(),
        language: z.string().optional(),
      }))
      .mutation(async ({ ctx, input }) => {
        const result = await transcribeAudio({
          audioUrl: input.audioUrl,
          language: input.language,
        });

        if ('error' in result) {
          throw new Error(result.error);
        }

        await db.createTranscription({
          userId: ctx.user.id,
          audioUrl: input.audioUrl,
          transcription: result.text,
          language: result.language,
        });

        return { text: result.text, language: result.language };
      }),

    getHistory: protectedProcedure.query(async ({ ctx }) => {
      return db.getUserTranscriptions(ctx.user.id);
    }),
  }),

  analysis: router({
    create: protectedProcedure
      .input(z.object({
        title: z.string(),
        data: z.string(),
        dataUrl: z.string().optional(),
        fileName: z.string().optional(),
        fileType: z.string().optional(),
      }))
      .mutation(async ({ ctx, input }) => {
        const response = await invokeLLM({
          messages: [
            { 
              role: "system", 
              content: "你是一个专业的数据分析师。分析用户提供的数据,提供洞察和建议。同时,为数据生成合适的图表配置(使用JSON格式,包含type、labels、datasets等字段,适用于Chart.js)。" 
            },
            { 
              role: "user", 
              content: `请分析以下数据并生成图表配置:\n\n${input.data}\n\n请按以下格式返回:\n分析结果:\n[你的分析内容]\n\n图表配置:\n[JSON格式的Chart.js配置]` 
            },
          ],
        });

        const content = response.choices[0]?.message?.content;
        const result = typeof content === 'string' ? content : "分析失败";
        
        let analysis = result;
        let chartData = null;

        const chartMatch = result.match(/图表配置[：:]\s*(\{[\s\S]*\})/);
        if (chartMatch) {
          try {
            chartData = chartMatch[1];
            const parts = result.split(/图表配置[：:]/);
            analysis = parts[0].replace(/分析结果[：:]\s*/, "").trim();
          } catch (e) {
            console.error("Failed to parse chart data:", e);
          }
        }

        const analysisId = await db.createDataAnalysis({
          userId: ctx.user.id,
          title: input.title,
          dataUrl: input.dataUrl,
          fileName: input.fileName,
          fileType: input.fileType,
          rawData: input.data,
          analysis,
          chartData,
        });

        return { id: analysisId, analysis, chartData };
      }),

    getHistory: protectedProcedure.query(async ({ ctx }) => {
      return db.getUserDataAnalysis(ctx.user.id);
    }),

    getById: protectedProcedure
      .input(z.object({ id: z.number() }))
      .query(async ({ input }) => {
        return db.getDataAnalysisById(input.id);
      }),
  }),

  storage: router({
    uploadAudio: protectedProcedure
      .input(z.object({
        filename: z.string(),
        contentType: z.string(),
        base64Data: z.string(),
      }))
      .mutation(async ({ ctx, input }) => {
        const buffer = Buffer.from(input.base64Data, 'base64');
        const fileKey = `${ctx.user.id}/audio/${Date.now()}-${input.filename}`;
        
        const { url } = await storagePut(fileKey, buffer, input.contentType);
        
        return { url };
      }),

    uploadDataFile: protectedProcedure
      .input(z.object({
        filename: z.string(),
        contentType: z.string(),
        base64Data: z.string(),
      }))
      .mutation(async ({ ctx, input }) => {
        const buffer = Buffer.from(input.base64Data, 'base64');
        const fileKey = `${ctx.user.id}/data/${Date.now()}-${input.filename}`;
        
        const { url } = await storagePut(fileKey, buffer, input.contentType);
        
        return { url, filename: input.filename, fileType: input.contentType };
      }),
  }),
});

export type AppRouter = typeof appRouter;

