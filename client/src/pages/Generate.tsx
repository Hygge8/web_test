import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { trpc } from "@/lib/trpc";
import { FileText, Image as ImageIcon, Loader2, Sparkles } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";

export default function Generate() {
  const [textPrompt, setTextPrompt] = useState("");
  const [imagePrompt, setImagePrompt] = useState("");
  const [textResult, setTextResult] = useState("");
  const [imageResult, setImageResult] = useState("");

  const generateText = trpc.generate.text.useMutation({
    onSuccess: (data) => {
      setTextResult(data.result);
      toast.success("文本生成成功");
    },
    onError: (error) => {
      toast.error("生成失败: " + error.message);
    },
  });

  const generateImage = trpc.generate.image.useMutation({
    onSuccess: (data) => {
      setImageResult(data.url);
      toast.success("图像生成成功");
    },
    onError: (error) => {
      toast.error("生成失败: " + error.message);
    },
  });

  const handleGenerateText = () => {
    if (!textPrompt.trim()) {
      toast.error("请输入生成提示");
      return;
    }
    generateText.mutate({ prompt: textPrompt });
  };

  const handleGenerateImage = () => {
    if (!imagePrompt.trim()) {
      toast.error("请输入图像描述");
      return;
    }
    generateImage.mutate({ prompt: imagePrompt });
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold flex items-center gap-2">
            <Sparkles className="w-8 h-8 text-primary" />
            智能内容生成
          </h1>
          <p className="text-muted-foreground mt-2">使用AI生成高质量的文本内容和精美图像</p>
        </div>

        <Tabs defaultValue="text" className="w-full">
          <TabsList className="grid w-full max-w-md grid-cols-2">
            <TabsTrigger value="text">
              <FileText className="w-4 h-4 mr-2" />
              文本生成
            </TabsTrigger>
            <TabsTrigger value="image">
              <ImageIcon className="w-4 h-4 mr-2" />
              图像生成
            </TabsTrigger>
          </TabsList>

          <TabsContent value="text" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>文本生成</CardTitle>
                <CardDescription>描述您想要生成的内容,AI将为您创作</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <Textarea
                  placeholder="例如: 写一篇关于人工智能发展的文章..."
                  value={textPrompt}
                  onChange={(e) => setTextPrompt(e.target.value)}
                  rows={4}
                  disabled={generateText.isPending}
                />
                <Button
                  onClick={handleGenerateText}
                  disabled={generateText.isPending}
                  className="w-full"
                >
                  {generateText.isPending ? (
                    <>
                      <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                      生成中...
                    </>
                  ) : (
                    <>
                      <Sparkles className="w-4 h-4 mr-2" />
                      生成文本
                    </>
                  )}
                </Button>
              </CardContent>
            </Card>

            {textResult && (
              <Card>
                <CardHeader>
                  <CardTitle>生成结果</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="prose max-w-none">
                    <p className="whitespace-pre-wrap">{textResult}</p>
                  </div>
                </CardContent>
              </Card>
            )}
          </TabsContent>

          <TabsContent value="image" className="space-y-4">
            <Card>
              <CardHeader>
                <CardTitle>图像生成</CardTitle>
                <CardDescription>描述您想要生成的图像,AI将为您创作</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <Textarea
                  placeholder="例如: 一幅美丽的日落海景,有帆船在远处..."
                  value={imagePrompt}
                  onChange={(e) => setImagePrompt(e.target.value)}
                  rows={4}
                  disabled={generateImage.isPending}
                />
                <Button
                  onClick={handleGenerateImage}
                  disabled={generateImage.isPending}
                  className="w-full"
                >
                  {generateImage.isPending ? (
                    <>
                      <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                      生成中...
                    </>
                  ) : (
                    <>
                      <ImageIcon className="w-4 h-4 mr-2" />
                      生成图像
                    </>
                  )}
                </Button>
              </CardContent>
            </Card>

            {imageResult && (
              <Card>
                <CardHeader>
                  <CardTitle>生成结果</CardTitle>
                </CardHeader>
                <CardContent>
                  <img
                    src={imageResult}
                    alt="Generated"
                    className="w-full rounded-lg shadow-lg"
                  />
                </CardContent>
              </Card>
            )}
          </TabsContent>
        </Tabs>
      </div>
    </DashboardLayout>
  );
}

