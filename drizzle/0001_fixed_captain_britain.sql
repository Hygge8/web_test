CREATE TABLE `conversations` (
	`id` int AUTO_INCREMENT NOT NULL,
	`userId` int NOT NULL,
	`title` varchar(255) NOT NULL,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `conversations_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `data_analysis` (
	`id` int AUTO_INCREMENT NOT NULL,
	`userId` int NOT NULL,
	`title` varchar(255) NOT NULL,
	`dataUrl` text,
	`analysis` text NOT NULL,
	`chartData` text,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `data_analysis_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `generated_content` (
	`id` int AUTO_INCREMENT NOT NULL,
	`userId` int NOT NULL,
	`type` enum('text','image') NOT NULL,
	`prompt` text NOT NULL,
	`result` text NOT NULL,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `generated_content_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `messages` (
	`id` int AUTO_INCREMENT NOT NULL,
	`conversationId` int NOT NULL,
	`role` enum('user','assistant','system') NOT NULL,
	`content` text NOT NULL,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `messages_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `transcriptions` (
	`id` int AUTO_INCREMENT NOT NULL,
	`userId` int NOT NULL,
	`audioUrl` text NOT NULL,
	`transcription` text NOT NULL,
	`language` varchar(10),
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `transcriptions_id` PRIMARY KEY(`id`)
);
