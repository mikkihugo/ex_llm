CREATE TABLE "approval_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"file_path" text NOT NULL,
	"diff" text NOT NULL,
	"description" text,
	"agent_id" varchar NOT NULL,
	"timestamp" timestamp DEFAULT now(),
	"approved" boolean,
	"approved_at" timestamp,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "hitl_metrics" (
	"id" integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "hitl_metrics_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START WITH 1 CACHE 1),
	"request_type" varchar(50) NOT NULL,
	"request_id" uuid NOT NULL,
	"response_time_ms" integer,
	"user_id" varchar,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "question_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"question" text NOT NULL,
	"context" jsonb,
	"agent_id" varchar NOT NULL,
	"timestamp" timestamp DEFAULT now(),
	"response" text,
	"response_at" timestamp,
	"created_at" timestamp DEFAULT now()
);
--> statement-breakpoint
CREATE INDEX "idx_approval_agent_id" ON "approval_requests" USING btree ("agent_id");--> statement-breakpoint
CREATE INDEX "idx_approval_timestamp" ON "approval_requests" USING btree ("timestamp");--> statement-breakpoint
CREATE INDEX "idx_question_agent_id" ON "question_requests" USING btree ("agent_id");--> statement-breakpoint
CREATE INDEX "idx_question_timestamp" ON "question_requests" USING btree ("timestamp");