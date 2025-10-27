import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Brain, LineChart, MessageSquare, Mic, Sparkles } from "lucide-react";
import { Link } from "wouter";

export default function Home() {
  const features = [
    {
      icon: MessageSquare,
      title: "AI对话",
      description: "与智能助手进行自然对话,获取即时帮助和建议",
      href: "/chat",
      color: "text-blue-500",
    },
    {
      icon: Brain,
      title: "内容生成",
      description: "使用AI生成高质量文本和精美图像",
      href: "/generate",
      color: "text-purple-500",
    },
    {
      icon: Mic,
      title: "语音转文字",
      description: "快速将音频文件转换为准确的文字记录",
      href: "/transcription",
      color: "text-green-500",
    },
    {
      icon: LineChart,
      title: "数据分析",
      description: "智能分析数据并生成可视化图表",
      href: "/analysis",
      color: "text-orange-500",
    },
  ];

  return (
    <DashboardLayout>
      <div className="space-y-8">
        {/* Hero Section */}
        <div className="text-center space-y-4 py-12">
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-primary/10 text-primary rounded-full text-sm font-medium mb-4">
            <Sparkles className="w-4 h-4" />
            <span>AI原生Web应用</span>
          </div>
          <h1 className="text-4xl md:text-5xl font-bold tracking-tight">
            欢迎使用AI智能助手平台
          </h1>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            集成多种AI能力,为您提供智能对话、内容生成、语音识别和数据分析等全方位服务
          </p>
        </div>

        {/* Features Grid */}
        <div className="grid md:grid-cols-2 gap-6">
          {features.map((feature) => {
            const Icon = feature.icon;
            return (
              <Card key={feature.title} className="hover:shadow-lg transition-shadow">
                <CardHeader>
                  <div className={`w-12 h-12 rounded-lg bg-background flex items-center justify-center mb-4 ${feature.color}`}>
                    <Icon className="w-6 h-6" />
                  </div>
                  <CardTitle>{feature.title}</CardTitle>
                  <CardDescription>{feature.description}</CardDescription>
                </CardHeader>
                <CardContent>
                  <Link href={feature.href}>
                    <Button variant="outline" className="w-full">
                      开始使用
                    </Button>
                  </Link>
                </CardContent>
              </Card>
            );
          })}
        </div>

        {/* Stats Section */}
        <Card className="bg-gradient-to-r from-primary/10 to-purple-500/10">
          <CardContent className="py-8">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-6 text-center">
              <div>
                <div className="text-3xl font-bold">4+</div>
                <div className="text-sm text-muted-foreground">核心功能</div>
              </div>
              <div>
                <div className="text-3xl font-bold">24/7</div>
                <div className="text-sm text-muted-foreground">全天候服务</div>
              </div>
              <div>
                <div className="text-3xl font-bold">∞</div>
                <div className="text-sm text-muted-foreground">无限可能</div>
              </div>
              <div>
                <div className="text-3xl font-bold">AI</div>
                <div className="text-sm text-muted-foreground">智能驱动</div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}

