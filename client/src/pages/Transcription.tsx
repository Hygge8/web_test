import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { trpc } from "@/lib/trpc";
import { Loader2, Mic, Upload } from "lucide-react";
import { useRef, useState } from "react";
import { toast } from "sonner";

const MAX_FILE_SIZE = 16 * 1024 * 1024; // 16MB

export default function Transcription() {
  const [file, setFile] = useState<File | null>(null);
  const [language, setLanguage] = useState("zh");
  const [transcriptionResult, setTranscriptionResult] = useState("");
  const fileInputRef = useRef<HTMLInputElement>(null);

  const uploadAudio = trpc.storage.uploadAudio.useMutation();
  const createTranscription = trpc.transcription.create.useMutation({
    onSuccess: (data) => {
      setTranscriptionResult(data.text);
      toast.success("转录完成");
    },
    onError: (error) => {
      toast.error("转录失败: " + error.message);
    },
  });

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = e.target.files?.[0];
    if (selectedFile) {
      if (selectedFile.size > MAX_FILE_SIZE) {
        toast.error("文件大小不能超过16MB");
        return;
      }
      setFile(selectedFile);
      setTranscriptionResult("");
    }
  };

  const handleTranscribe = async () => {
    if (!file) {
      toast.error("请选择音频文件");
      return;
    }

    try {
      // Convert file to base64
      const reader = new FileReader();
      reader.onload = async (e) => {
        const base64Data = e.target?.result as string;
        const base64Content = base64Data.split(",")[1];

        // Upload to S3
        const uploadResult = await uploadAudio.mutateAsync({
          filename: file.name,
          contentType: file.type,
          base64Data: base64Content,
        });

        // Transcribe
        await createTranscription.mutateAsync({
          audioUrl: uploadResult.url,
          language: language || undefined,
        });
      };
      reader.readAsDataURL(file);
    } catch (error) {
      console.error("Transcription error:", error);
    }
  };

  const isProcessing = uploadAudio.isPending || createTranscription.isPending;

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold flex items-center gap-2">
            <Mic className="w-8 h-8 text-primary" />
            语音转文字
          </h1>
          <p className="text-muted-foreground mt-2">上传音频文件,快速转换为文字记录</p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>上传音频文件</CardTitle>
            <CardDescription>
              支持格式: MP3, WAV, M4A, OGG, WEBM (最大16MB)
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="audio-file">音频文件</Label>
              <div className="flex gap-2">
                <Input
                  id="audio-file"
                  type="file"
                  accept="audio/*"
                  ref={fileInputRef}
                  onChange={handleFileChange}
                  disabled={isProcessing}
                  className="flex-1"
                />
                <Button
                  variant="outline"
                  onClick={() => fileInputRef.current?.click()}
                  disabled={isProcessing}
                >
                  <Upload className="w-4 h-4 mr-2" />
                  选择文件
                </Button>
              </div>
              {file && (
                <p className="text-sm text-muted-foreground">
                  已选择: {file.name} ({(file.size / 1024 / 1024).toFixed(2)} MB)
                </p>
              )}
            </div>

            <div className="space-y-2">
              <Label htmlFor="language">语言 (可选)</Label>
              <Input
                id="language"
                placeholder="例如: zh, en, ja"
                value={language}
                onChange={(e) => setLanguage(e.target.value)}
                disabled={isProcessing}
              />
              <p className="text-xs text-muted-foreground">
                指定语言可以提高识别准确度
              </p>
            </div>

            <Button
              onClick={handleTranscribe}
              disabled={!file || isProcessing}
              className="w-full"
            >
              {isProcessing ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  处理中...
                </>
              ) : (
                <>
                  <Mic className="w-4 h-4 mr-2" />
                  开始转录
                </>
              )}
            </Button>
          </CardContent>
        </Card>

        {transcriptionResult && (
          <Card>
            <CardHeader>
              <CardTitle>转录结果</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="prose max-w-none">
                <p className="whitespace-pre-wrap">{transcriptionResult}</p>
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </DashboardLayout>
  );
}

