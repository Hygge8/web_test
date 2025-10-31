import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { trpc } from "@/lib/trpc";
import { BarChart3, FileUp, LineChart, Loader2, Upload } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";
import Papa from "papaparse";
import * as XLSX from "xlsx";

export default function Analysis() {
  const [title, setTitle] = useState("");
  const [data, setData] = useState("");
  const [analysisResult, setAnalysisResult] = useState("");
  const [chartData, setChartData] = useState<any>(null);
  const [uploadedFile, setUploadedFile] = useState<File | null>(null);
  const [fileData, setFileData] = useState<{
    url?: string;
    fileName?: string;
    fileType?: string;
  }>({});
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const uploadFile = trpc.storage.uploadDataFile.useMutation({
    onSuccess: (result) => {
      setFileData({
        url: result.url,
        fileName: result.filename,
        fileType: result.fileType,
      });
      toast.success("文件上传成功");
    },
    onError: (error) => {
      toast.error("文件上传失败: " + error.message);
    },
  });

  const createAnalysis = trpc.analysis.create.useMutation({
    onSuccess: (result) => {
      setAnalysisResult(result.analysis);
      if (result.chartData) {
        try {
          const parsed = JSON.parse(result.chartData);
          setChartData(parsed);
        } catch (e) {
          console.error("Failed to parse chart data:", e);
        }
      }
      toast.success("分析完成");
      // 清空表单
      setTitle("");
      setData("");
      setUploadedFile(null);
      setFileData({});
    },
    onError: (error) => {
      toast.error("分析失败: " + error.message);
    },
  });

  useEffect(() => {
    if (chartData && canvasRef.current) {
      import("chart.js/auto").then((ChartJS) => {
        const ctx = canvasRef.current?.getContext("2d");
        if (ctx) {
          const existingChart = ChartJS.Chart.getChart(canvasRef.current!);
          if (existingChart) {
            existingChart.destroy();
          }
          new ChartJS.Chart(ctx, chartData);
        }
      });
    }
  }, [chartData]);

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // 检查文件大小 (最大10MB)
    if (file.size > 10 * 1024 * 1024) {
      toast.error("文件大小不能超过10MB");
      return;
    }

    // 检查文件类型
    const validTypes = [
      "text/csv",
      "application/vnd.ms-excel",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ];
    if (!validTypes.includes(file.type) && !file.name.match(/\.(csv|xlsx|xls)$/i)) {
      toast.error("仅支持CSV和Excel文件");
      return;
    }

    setUploadedFile(file);

    // 解析文件内容
    try {
      let parsedData = "";
      
      if (file.name.endsWith(".csv") || file.type === "text/csv") {
        // 解析CSV
        Papa.parse(file, {
          complete: (results) => {
            parsedData = JSON.stringify(results.data, null, 2);
            setData(parsedData);
          },
          error: (error) => {
            toast.error("CSV解析失败: " + error.message);
          },
        });
      } else if (file.name.match(/\.(xlsx|xls)$/i)) {
        // 解析Excel
        const reader = new FileReader();
        reader.onload = (e) => {
          try {
            const data = new Uint8Array(e.target?.result as ArrayBuffer);
            const workbook = XLSX.read(data, { type: "array" });
            const firstSheet = workbook.Sheets[workbook.SheetNames[0]];
            const jsonData = XLSX.utils.sheet_to_json(firstSheet);
            parsedData = JSON.stringify(jsonData, null, 2);
            setData(parsedData);
          } catch (error) {
            toast.error("Excel解析失败");
          }
        };
        reader.readAsArrayBuffer(file);
      }

      // 上传文件到S3
      const reader = new FileReader();
      reader.onload = () => {
        const base64 = (reader.result as string).split(",")[1];
        uploadFile.mutate({
          filename: file.name,
          contentType: file.type || "application/octet-stream",
          base64Data: base64,
        });
      };
      reader.readAsDataURL(file);
    } catch (error) {
      toast.error("文件处理失败");
    }
  };

  const handleAnalyze = () => {
    if (!title.trim()) {
      toast.error("请输入分析标题");
      return;
    }
    if (!data.trim()) {
      toast.error("请输入或上传要分析的数据");
      return;
    }

    createAnalysis.mutate({
      title,
      data,
      dataUrl: fileData.url,
      fileName: fileData.fileName,
      fileType: fileData.fileType,
    });
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold flex items-center gap-2">
            <LineChart className="w-8 h-8 text-primary" />
            数据分析与可视化
          </h1>
          <p className="text-muted-foreground mt-2">
            上传数据文件或手动输入数据,AI将为您提供深入分析和可视化图表
          </p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <BarChart3 className="w-5 h-5" />
              创建新分析
            </CardTitle>
            <CardDescription>
              支持CSV和Excel文件,或直接输入JSON格式数据
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="title">分析标题</Label>
              <Input
                id="title"
                placeholder="例如: 2024年销售数据分析"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
              />
            </div>

            <Tabs defaultValue="upload" className="w-full">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="upload">上传文件</TabsTrigger>
                <TabsTrigger value="manual">手动输入</TabsTrigger>
              </TabsList>

              <TabsContent value="upload" className="space-y-4">
                <div className="space-y-2">
                  <Label>数据文件</Label>
                  <div className="flex items-center gap-2">
                    <Input
                      ref={fileInputRef}
                      type="file"
                      accept=".csv,.xlsx,.xls"
                      onChange={handleFileSelect}
                      className="hidden"
                    />
                    <Button
                      type="button"
                      variant="outline"
                      onClick={() => fileInputRef.current?.click()}
                      className="w-full"
                    >
                      <FileUp className="w-4 h-4 mr-2" />
                      {uploadedFile ? uploadedFile.name : "选择CSV或Excel文件"}
                    </Button>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    支持CSV、XLSX、XLS格式,最大10MB
                  </p>
                </div>

                {data && (
                  <div className="space-y-2">
                    <Label>解析后的数据预览</Label>
                    <Textarea
                      value={data}
                      onChange={(e) => setData(e.target.value)}
                      placeholder="文件数据将显示在这里..."
                      className="font-mono text-sm min-h-[200px]"
                    />
                  </div>
                )}
              </TabsContent>

              <TabsContent value="manual" className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="data">数据内容</Label>
                  <Textarea
                    id="data"
                    placeholder='输入JSON格式数据,例如: [{"月份": "1月", "销售额": 1000}, {"月份": "2月", "销售额": 1500}]'
                    value={data}
                    onChange={(e) => setData(e.target.value)}
                    className="font-mono text-sm min-h-[200px]"
                  />
                  <p className="text-sm text-muted-foreground">
                    支持JSON数组格式或CSV格式文本
                  </p>
                </div>
              </TabsContent>
            </Tabs>

            <Button
              onClick={handleAnalyze}
              disabled={createAnalysis.isPending || uploadFile.isPending}
              className="w-full"
            >
              {createAnalysis.isPending ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  分析中...
                </>
              ) : (
                <>
                  <BarChart3 className="w-4 h-4 mr-2" />
                  开始分析
                </>
              )}
            </Button>
          </CardContent>
        </Card>

        {analysisResult && (
          <Card>
            <CardHeader>
              <CardTitle>分析结果</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="prose max-w-none">
                <pre className="whitespace-pre-wrap bg-muted p-4 rounded-lg">
                  {analysisResult}
                </pre>
              </div>

              {chartData && (
                <div className="mt-6">
                  <h3 className="text-lg font-semibold mb-4">数据可视化</h3>
                  <div className="bg-white p-4 rounded-lg border">
                    <canvas ref={canvasRef}></canvas>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        )}
      </div>
    </DashboardLayout>
  );
}

