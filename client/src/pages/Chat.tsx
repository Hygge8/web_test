import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { ScrollArea } from "@/components/ui/scroll-area";
import { trpc } from "@/lib/trpc";
import { Loader2, MessageSquare, Plus, Send, Trash2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { toast } from "sonner";

export default function Chat() {
  const [selectedConversation, setSelectedConversation] = useState<number | null>(null);
  const [message, setMessage] = useState("");
  const scrollRef = useRef<HTMLDivElement>(null);

  const { data: conversations, refetch: refetchConversations } = trpc.chat.getConversations.useQuery();
  const { data: messages, refetch: refetchMessages } = trpc.chat.getMessages.useQuery(
    { conversationId: selectedConversation! },
    { enabled: !!selectedConversation }
  );

  const createConversation = trpc.chat.createConversation.useMutation({
    onSuccess: (data) => {
      setSelectedConversation(data.id);
      refetchConversations();
      toast.success("新对话已创建");
    },
  });

  const sendMessage = trpc.chat.sendMessage.useMutation({
    onSuccess: () => {
      refetchMessages();
      setMessage("");
    },
    onError: (error) => {
      toast.error("发送失败: " + error.message);
    },
  });

  const deleteConversation = trpc.chat.deleteConversation.useMutation({
    onSuccess: () => {
      setSelectedConversation(null);
      refetchConversations();
      toast.success("对话已删除");
    },
  });

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  const handleNewConversation = () => {
    const title = `对话 ${new Date().toLocaleString("zh-CN")}`;
    createConversation.mutate({ title });
  };

  const handleSendMessage = () => {
    if (!message.trim() || !selectedConversation) return;
    sendMessage.mutate({
      conversationId: selectedConversation,
      content: message,
    });
  };

  return (
    <DashboardLayout>
      <div className="h-[calc(100vh-8rem)] flex gap-4">
        {/* Conversations List */}
        <Card className="w-80 flex flex-col">
          <div className="p-4 border-b">
            <Button onClick={handleNewConversation} className="w-full" disabled={createConversation.isPending}>
              <Plus className="w-4 h-4 mr-2" />
              新建对话
            </Button>
          </div>
          <ScrollArea className="flex-1">
            <div className="p-2 space-y-2">
              {conversations?.map((conv) => (
                <div
                  key={conv.id}
                  className={`p-3 rounded-lg cursor-pointer hover:bg-accent transition-colors group ${
                    selectedConversation === conv.id ? "bg-accent" : ""
                  }`}
                  onClick={() => setSelectedConversation(conv.id)}
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex-1 min-w-0">
                      <p className="font-medium truncate">{conv.title}</p>
                      <p className="text-xs text-muted-foreground">
                        {new Date(conv.updatedAt).toLocaleString("zh-CN")}
                      </p>
                    </div>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="opacity-0 group-hover:opacity-100 h-8 w-8"
                      onClick={(e) => {
                        e.stopPropagation();
                        deleteConversation.mutate({ id: conv.id });
                      }}
                    >
                      <Trash2 className="w-4 h-4 text-destructive" />
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          </ScrollArea>
        </Card>

        {/* Chat Area */}
        <Card className="flex-1 flex flex-col">
          {selectedConversation ? (
            <>
              <div className="p-4 border-b">
                <h2 className="font-semibold">
                  {conversations?.find((c) => c.id === selectedConversation)?.title}
                </h2>
              </div>
              <ScrollArea className="flex-1 p-4" ref={scrollRef}>
                <div className="space-y-4">
                  {messages?.map((msg) => (
                    <div
                      key={msg.id}
                      className={`flex ${msg.role === "user" ? "justify-end" : "justify-start"}`}
                    >
                      <div
                        className={`max-w-[70%] rounded-lg p-3 ${
                          msg.role === "user"
                            ? "bg-primary text-primary-foreground"
                            : "bg-muted"
                        }`}
                      >
                        <p className="whitespace-pre-wrap">{msg.content}</p>
                      </div>
                    </div>
                  ))}
                  {sendMessage.isPending && (
                    <div className="flex justify-start">
                      <div className="bg-muted rounded-lg p-3">
                        <Loader2 className="w-5 h-5 animate-spin" />
                      </div>
                    </div>
                  )}
                </div>
              </ScrollArea>
              <div className="p-4 border-t">
                <div className="flex gap-2">
                  <Input
                    placeholder="输入消息..."
                    value={message}
                    onChange={(e) => setMessage(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter" && !e.shiftKey) {
                        e.preventDefault();
                        handleSendMessage();
                      }
                    }}
                    disabled={sendMessage.isPending}
                  />
                  <Button onClick={handleSendMessage} disabled={sendMessage.isPending || !message.trim()}>
                    <Send className="w-4 h-4" />
                  </Button>
                </div>
              </div>
            </>
          ) : (
            <div className="flex-1 flex items-center justify-center text-muted-foreground">
              <div className="text-center space-y-2">
                <MessageSquare className="w-12 h-12 mx-auto opacity-50" />
                <p>选择或创建一个对话开始聊天</p>
              </div>
            </div>
          )}
        </Card>
      </div>
    </DashboardLayout>
  );
}

