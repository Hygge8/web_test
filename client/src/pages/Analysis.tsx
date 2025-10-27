import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { trpc } from "@/lib/trpc";
import { BarChart3, LineChart, Loader2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";

export default function Analysis() {
  const [title, setTitle] = useState("");
  const [data, setData] = useState("");
  const [analysisResult, setAnalysisResult] = useState("");
  const [chartData, setChartData] = useState<any>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

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
          // Clear previous chart
          const existingChart = ChartJS.Chart.getChart(canvasRef.current!);
          if (existingChart) {
            existingChart.destroy();
          }

          // Create new chart
          new ChartJS.Chart(ctx, chartData);
        }
      });
    }
  }, [chartData]);

  const handleAnalyze = () => {
    if (!title.trim()) {
      toast.error("请输入分析标题");
      return;
    }
    if (!data.trim()) {
      toast.error("请输入要分析的数据");
      return;
    }

    createAnalysis.mutate({ title, data });
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
            输入数据,AI将为您提供深入分析和可视化图表
          </p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>数据输入</CardTitle>
            <CardDescription>
              输入您想要分析的数据,可以是数字、文本或表格格式
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
                disabled={createAnalysis.isPending}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="data">数据内容</Label>
              <Textarea
                id="data"
                placeholder="例如:&#10;一月: 1000&#10;二月: 1500&#10;三月: 1200&#10;四月: 1800&#10;五月: 2000"
                value={data}
                onChange={(e) => setData(e.target.value)}
                rows={8}
                disabled={createAnalysis.isPending}
              />
            </div>

            <Button
              onClick={handleAnalyze}
              disabled={createAnalysis.isPending}
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
                <p className="whitespace-pre-wrap">{analysisResult}</p>
              </div>

              {chartData && (
                <div className="mt-6">
                  <h3 className="text-lg font-semibold mb-4">数据可视化</h3>
                  <div className="bg-background p-4 rounded-lg">
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

