import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { trpc } from "@/lib/trpc";
import { Bell, Trash2, Check, Loader2 } from "lucide-react";
import { useEffect, useState } from "react";
import { toast } from "sonner";

export default function Notifications() {
  const [notifications, setNotifications] = useState<any[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);

  const getNotifications = trpc.notifications.getNotifications.useQuery(undefined, {
    refetchInterval: 5000,
  });

  const getUnreadCount = trpc.notifications.getUnreadCount.useQuery(undefined, {
    refetchInterval: 5000,
  });

  const markAsRead = trpc.notifications.markAsRead.useMutation({
    onSuccess: () => {
      getNotifications.refetch();
      getUnreadCount.refetch();
    },
    onError: (error) => {
      toast.error("Failed to mark as read: " + error.message);
    },
  });

  const deleteNotification = trpc.notifications.delete.useMutation({
    onSuccess: () => {
      getNotifications.refetch();
      getUnreadCount.refetch();
    },
    onError: (error) => {
      toast.error("Failed to delete notification: " + error.message);
    },
  });

  useEffect(() => {
    if (getNotifications.data) {
      setNotifications(getNotifications.data);
    }
  }, [getNotifications.data]);

  useEffect(() => {
    if (getUnreadCount.data !== undefined) {
      setUnreadCount(getUnreadCount.data);
    }
  }, [getUnreadCount.data]);

  const getTypeColor = (type: string) => {
    switch (type) {
      case "analysis_complete":
        return "bg-blue-100 text-blue-800";
      case "generation_complete":
        return "bg-purple-100 text-purple-800";
      case "transcription_complete":
        return "bg-green-100 text-green-800";
      case "system":
        return "bg-gray-100 text-gray-800";
      default:
        return "bg-gray-100 text-gray-800";
    }
  };

  const getTypeLabel = (type: string) => {
    switch (type) {
      case "analysis_complete":
        return "Analysis";
      case "generation_complete":
        return "Generation";
      case "transcription_complete":
        return "Transcription";
      case "system":
        return "System";
      default:
        return type;
    }
  };

  const formatDate = (date: Date) => {
    const now = new Date();
    const diff = now.getTime() - new Date(date).getTime();
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 1) return "Just now";
    if (minutes < 60) return `${minutes}m ago`;
    if (hours < 24) return `${hours}h ago`;
    if (days < 7) return `${days}d ago`;

    return new Date(date).toLocaleDateString();
  };

  return (
    <DashboardLayout>
      <div className="space-y-6">
        <div>
          <h1 className="text-3xl font-bold flex items-center gap-2">
            <Bell className="w-8 h-8 text-primary" />
            Notifications
          </h1>
          <p className="text-muted-foreground mt-2">
            {unreadCount > 0 ? (
              <>
                You have <span className="font-semibold">{unreadCount}</span> unread notifications
              </>
            ) : (
              "All notifications read"
            )}
          </p>
        </div>

        {notifications.length === 0 ? (
          <Card>
            <CardContent className="pt-8 text-center">
              <Bell className="w-12 h-12 text-muted-foreground mx-auto mb-4 opacity-50" />
              <p className="text-muted-foreground">No notifications yet</p>
            </CardContent>
          </Card>
        ) : (
          <div className="space-y-3">
            {notifications.map((notification) => (
              <Card
                key={notification.id}
                className={notification.isRead === 0 ? "border-primary/50 bg-primary/5" : ""}
              >
                <CardContent className="pt-6">
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-2">
                        <h3 className="font-semibold">{notification.title}</h3>
                        <Badge className={getTypeColor(notification.type)}>
                          {getTypeLabel(notification.type)}
                        </Badge>
                        {notification.isRead === 0 && (
                          <Badge variant="default">New</Badge>
                        )}
                      </div>
                      <p className="text-sm text-muted-foreground mb-2">
                        {notification.content}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {formatDate(notification.createdAt)}
                      </p>
                    </div>
                    <div className="flex gap-2">
                      {notification.isRead === 0 && (
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => markAsRead.mutate({ id: notification.id })}
                          disabled={markAsRead.isPending}
                        >
                          {markAsRead.isPending ? (
                            <Loader2 className="w-4 h-4 animate-spin" />
                          ) : (
                            <Check className="w-4 h-4" />
                          )}
                        </Button>
                      )}
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => deleteNotification.mutate({ id: notification.id })}
                        disabled={deleteNotification.isPending}
                      >
                        {deleteNotification.isPending ? (
                          <Loader2 className="w-4 h-4 animate-spin" />
                        ) : (
                          <Trash2 className="w-4 h-4" />
                        )}
                      </Button>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}

