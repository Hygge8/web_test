import DashboardLayout from "@/components/DashboardLayout";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { trpc } from "@/lib/trpc";
import { FileText, History as HistoryIcon, Image as ImageIcon, Loader2, Mic } from "lucide-react";

export default function History() {
  const { data: textHistory, isLoading: textLoading } = trpc.generate.getHistory.useQuery({ type: "text" });
  const { data: imageHistory, isLoading: imageLoading } = trpc.generate.getHistory.useQuery({ type: "image" });
  const { data: transcriptions, isLoading: transcriptionLoading } = trpc.transcription.getHistory.useQuery();

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold flex items-center gap-2">
            <HistoryIcon className="w-8 h-8 text-primary" />
            历史记录
          </h1>
          <p className="text-muted-foreground mt-2">查看您的所有生成和转录历史</p>
        </div>

        <Tabs defaultValue="text" className="w-full">
          <TabsList className="grid w-full max-w-2xl grid-cols-3">
            <TabsTrigger value="text">
              <FileText className="w-4 h-4 mr-2" />
              文本生成
            </TabsTrigger>
            <TabsTrigger value="image">
              <ImageIcon className="w-4 h-4 mr-2" />
              图像生成
            </TabsTrigger>
            <TabsTrigger value="transcription">
              <Mic className="w-4 h-4 mr-2" />
              语音转录
            </TabsTrigger>
          </TabsList>

          <TabsContent value="text" className="space-y-4">
            {textLoading ? (
              <div className="flex justify-center py-8">
                <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
              </div>
            ) : textHistory && textHistory.length > 0 ? (
              textHistory.map((item) => (
                <Card key={item.id}>
                  <CardHeader>
                    <CardTitle className="text-base">提示词</CardTitle>
                    <CardDescription>{item.prompt}</CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="prose max-w-none">
                      <p className="whitespace-pre-wrap text-sm">{item.result}</p>
                    </div>
                    <p className="text-xs text-muted-foreground mt-4">
                      {new Date(item.createdAt).toLocaleString("zh-CN")}
                    </p>
                  </CardContent>
                </Card>
              ))
            ) : (
              <Card>
                <CardContent className="py-8 text-center text-muted-foreground">
                  暂无文本生成记录
                </CardContent>
              </Card>
            )}
          </TabsContent>

          <TabsContent value="image" className="space-y-4">
            {imageLoading ? (
              <div className="flex justify-center py-8">
                <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
              </div>
            ) : imageHistory && imageHistory.length > 0 ? (
              <div className="grid md:grid-cols-2 gap-4">
                {imageHistory.map((item) => (
                  <Card key={item.id}>
                    <CardHeader>
                      <CardTitle className="text-base">提示词</CardTitle>
                      <CardDescription>{item.prompt}</CardDescription>
                    </CardHeader>
                    <CardContent>
                      <img
                        src={item.result}
                        alt={item.prompt}
                        className="w-full rounded-lg shadow-md"
                      />
                      <p className="text-xs text-muted-foreground mt-4">
                        {new Date(item.createdAt).toLocaleString("zh-CN")}
                      </p>
                    </CardContent>
                  </Card>
                ))}
              </div>
            ) : (
              <Card>
                <CardContent className="py-8 text-center text-muted-foreground">
                  暂无图像生成记录
                </CardContent>
              </Card>
            )}
          </TabsContent>

          <TabsContent value="transcription" className="space-y-4">
            {transcriptionLoading ? (
              <div className="flex justify-center py-8">
                <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
              </div>
            ) : transcriptions && transcriptions.length > 0 ? (
              transcriptions.map((item) => (
                <Card key={item.id}>
                  <CardHeader>
                    <CardTitle className="text-base">音频文件</CardTitle>
                    <CardDescription>
                      语言: {item.language || "未指定"}
                    </CardDescription>
                  </CardHeader>
                  <CardContent>
                    <div className="prose max-w-none">
                      <p className="whitespace-pre-wrap text-sm">{item.transcription}</p>
                    </div>
                    <p className="text-xs text-muted-foreground mt-4">
                      {new Date(item.createdAt).toLocaleString("zh-CN")}
                    </p>
                  </CardContent>
                </Card>
              ))
            ) : (
              <Card>
                <CardContent className="py-8 text-center text-muted-foreground">
                  暂无语音转录记录
                </CardContent>
              </Card>
            )}
          </TabsContent>
        </Tabs>
      </div>
    </DashboardLayout>
  );
}

