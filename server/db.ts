import { and, desc, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/mysql2";
import { 
  InsertUser, 
  users, 
  conversations,
  messages,
  generatedContent,
  transcriptions,
  dataAnalysis,
  notifications,
  InsertConversation,
  InsertMessage,
  InsertGeneratedContent,
  InsertTranscription,
  InsertDataAnalysis,
  InsertNotification
} from "../drizzle/schema";
import { ENV } from './_core/env';

let _db: ReturnType<typeof drizzle> | null = null;

export async function getDb() {
  if (!_db && process.env.DATABASE_URL) {
    try {
      _db = drizzle(process.env.DATABASE_URL);
    } catch (error) {
      console.warn("[Database] Failed to connect:", error);
      _db = null;
    }
  }
  return _db;
}

export async function upsertUser(user: InsertUser): Promise<void> {
  if (!user.openId) {
    throw new Error("User openId is required for upsert");
  }

  const db = await getDb();
  if (!db) {
    console.warn("[Database] Cannot upsert user: database not available");
    return;
  }

  try {
    const values: InsertUser = {
      openId: user.openId,
    };
    const updateSet: Record<string, unknown> = {};

    const textFields = ["name", "email", "loginMethod"] as const;
    type TextField = (typeof textFields)[number];

    const assignNullable = (field: TextField) => {
      const value = user[field];
      if (value === undefined) return;
      const normalized = value ?? null;
      values[field] = normalized;
      updateSet[field] = normalized;
    };

    textFields.forEach(assignNullable);

    if (user.lastSignedIn !== undefined) {
      values.lastSignedIn = user.lastSignedIn;
      updateSet.lastSignedIn = user.lastSignedIn;
    }
    if (user.role !== undefined) {
      values.role = user.role;
      updateSet.role = user.role;
    } else if (user.openId === ENV.ownerOpenId) {
      values.role = 'admin';
      updateSet.role = 'admin';
    }

    if (!values.lastSignedIn) {
      values.lastSignedIn = new Date();
    }

    if (Object.keys(updateSet).length === 0) {
      updateSet.lastSignedIn = new Date();
    }

    await db.insert(users).values(values).onDuplicateKeyUpdate({
      set: updateSet,
    });
  } catch (error) {
    console.error("[Database] Failed to upsert user:", error);
    throw error;
  }
}

export async function getUserByOpenId(openId: string) {
  const db = await getDb();
  if (!db) {
    console.warn("[Database] Cannot get user: database not available");
    return undefined;
  }

  const result = await db.select().from(users).where(eq(users.openId, openId)).limit(1);

  return result.length > 0 ? result[0] : undefined;
}

// Conversation queries
export async function createConversation(data: InsertConversation) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");
  
  const result = await db.insert(conversations).values(data);
  return result[0].insertId;
}

export async function getUserConversations(userId: number) {
  const db = await getDb();
  if (!db) return [];
  
  return db.select().from(conversations).where(eq(conversations.userId, userId)).orderBy(desc(conversations.updatedAt));
}

export async function getConversation(id: number) {
  const db = await getDb();
  if (!db) return undefined;
  
  const result = await db.select().from(conversations).where(eq(conversations.id, id)).limit(1);
  return result.length > 0 ? result[0] : undefined;
}

export async function deleteConversation(id: number) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");
  
  await db.delete(messages).where(eq(messages.conversationId, id));
  await db.delete(conversations).where(eq(conversations.id, id));
}

// Message queries
export async function createMessage(data: InsertMessage) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");
  
  const result = await db.insert(messages).values(data);
  return result[0].insertId;
}

export async function getConversationMessages(conversationId: number) {
  const db = await getDb();
  if (!db) return [];
  
  return db.select().from(messages).where(eq(messages.conversationId, conversationId)).orderBy(messages.createdAt);
}

// Generated content queries
export async function createGeneratedContent(data: InsertGeneratedContent) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");
  
  const result = await db.insert(generatedContent).values(data);
  return result[0].insertId;
}

export async function getUserGeneratedContent(userId: number, type?: "text" | "image") {
  const db = await getDb();
  if (!db) return [];
  
  if (type) {
    return db.select().from(generatedContent)
      .where(and(eq(generatedContent.userId, userId), eq(generatedContent.type, type)))
      .orderBy(desc(generatedContent.createdAt));
  }
  
  return db.select().from(generatedContent)
    .where(eq(generatedContent.userId, userId))
    .orderBy(desc(generatedContent.createdAt));
}

// Transcription queries
export async function createTranscription(data: InsertTranscription) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");
  
  const result = await db.insert(transcriptions).values(data);
  return result[0].insertId;
}

export async function getUserTranscriptions(userId: number) {
  const db = await getDb();
  if (!db) return [];
  
  return db.select().from(transcriptions).where(eq(transcriptions.userId, userId)).orderBy(desc(transcriptions.createdAt));
}

// Data analysis queries
export async function createDataAnalysis(data: InsertDataAnalysis) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");
  
  const result = await db.insert(dataAnalysis).values(data);
  return result[0].insertId;
}

export async function getUserDataAnalysis(userId: number) {
  const db = await getDb();
  if (!db) return [];
  
  return db.select().from(dataAnalysis).where(eq(dataAnalysis.userId, userId)).orderBy(desc(dataAnalysis.createdAt));
}

export async function getDataAnalysisById(id: number) {
  const db = await getDb();
  if (!db) return undefined;
  
  const result = await db.select().from(dataAnalysis).where(eq(dataAnalysis.id, id)).limit(1);
  return result.length > 0 ? result[0] : undefined;
}

// Notification functions
export async function createNotification(notification: InsertNotification): Promise<number> {
  const db = await getDb();
  if (!db) throw new Error("Database not available");
  
  const result = await db.insert(notifications).values(notification);
  return (result as any).insertId as number;
}

export async function getUserNotifications(userId: number) {
  const db = await getDb();
  if (!db) return [];
  
  return db.select().from(notifications).where(eq(notifications.userId, userId)).orderBy(desc(notifications.createdAt));
}

export async function markNotificationAsRead(id: number) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");
  
  await db.update(notifications).set({ isRead: 1 }).where(eq(notifications.id, id));
}

export async function deleteNotification(id: number) {
  const db = await getDb();
  if (!db) throw new Error("Database not available");
  
  await db.delete(notifications).where(eq(notifications.id, id));
}

export async function getUnreadNotificationCount(userId: number) {
  const db = await getDb();
  if (!db) return 0;
  
  const result = await db.select().from(notifications).where(and(eq(notifications.userId, userId), eq(notifications.isRead, 0)));
  return result.length;
}

