import { useState, useRef, useEffect } from "react";
import { useTranslation } from "react-i18next";
import { useMutation } from "@tanstack/react-query";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import {
  Send,
  Bot,
  User,
  Loader2,
  Sparkles,
  CheckCircle2,
  XCircle,
  Cpu,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { sendAgentChat, submitJob } from "@/lib/api";
import type { AgentChatMessage, ProposedAction } from "@/lib/types";

export default function Agent() {
  const { i18n } = useTranslation();
  const [messages, setMessages] = useState<AgentChatMessage[]>([]);
  const [input, setInput] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const chatMutation = useMutation({
    mutationFn: (msg: string) => sendAgentChat(msg, messages),
    onSuccess: (data) => {
      setMessages((prev) => [
        ...prev,
        {
          role: "assistant",
          content: data.content,
          model: data.model,
          actions: data.actions,
        },
      ]);
    },
    onError: (err: Error) => {
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: `Error: ${err.message}` },
      ]);
    },
  });

  const sendMessage = () => {
    const text = input.trim();
    if (!text || chatMutation.isPending) return;

    setMessages((prev) => [...prev, { role: "user", content: text }]);
    setInput("");
    chatMutation.mutate(text);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  const handleApprove = async (action: ProposedAction) => {
    try {
      await submitJob({
        instance_type: action.instance_type ?? "g6.xlarge",
        image: action.image ?? "nvidia/cuda:12.2.0-runtime-ubuntu22.04",
        command: action.command
          ? ["/bin/sh", "-c", action.command]
          : ["nvidia-smi"],
        gpu_type: action.instance_type?.startsWith("g6e")
          ? "L40S"
          : action.instance_type?.startsWith("g6")
            ? "L4"
            : "A10G",
        gpu_count: action.gpu_count ?? 1,
        storage_mode: "s3",
        checkpoint_enabled: false,
      });
      setMessages((prev) => [
        ...prev,
        {
          role: "assistant",
          content: `**${action.region ?? "auto"}** 리전에 작업이 제출되었습니다. Jobs 페이지에서 상태를 확인하세요.`,
        },
      ]);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Unknown error";
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: `작업 제출 실패: ${msg}` },
      ]);
    }
  };

  const isKo = i18n.language === "ko";
  const suggestions = isKo
    ? [
        "현재 가장 저렴한 GPU 스팟 가격을 알려줘",
        "g6.xlarge로 LoRA 파인튜닝 작업을 제출해줘",
        "현재 활성 작업과 대기열 상태는?",
        "24GB VRAM이 필요한데 어떤 인스턴스를 써야 해?",
        "각 리전별 용량과 가격을 비교해줘",
        "A10G x4로 대규모 학습을 돌리고 싶어",
      ]
    : [
        "Show me the cheapest GPU spot prices right now",
        "Submit a LoRA fine-tuning job on g6.xlarge",
        "What's the current queue and active job status?",
        "I need 24GB VRAM — which instance should I use?",
        "Compare capacity and prices across all regions",
        "I want to run large-scale training on A10G x4",
      ];

  return (
    <div className="flex h-[calc(100vh-3.5rem)] flex-col">
      {/* Messages area */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
        {/* Welcome state */}
        {messages.length === 0 && (
          <div className="flex flex-col items-center justify-center py-16">
            <div className="mb-4 rounded-2xl bg-primary/10 p-4">
              <Sparkles className="h-10 w-10 text-primary" />
            </div>
            <h2 className="mb-2 text-xl font-semibold">GPU Spot Lotto AI Agent</h2>
            <p className="mb-6 max-w-md text-center text-sm text-muted-foreground">
              {isKo
                ? "GPU 스팟 가격 조회, 작업 제출, 인프라 상태를 자연어로 질문하세요."
                : "Ask about GPU spot prices, submit jobs, or check infrastructure status."}
            </p>
            <div className="grid w-full max-w-2xl grid-cols-1 gap-2 md:grid-cols-2">
              {suggestions.map((s, i) => (
                <button
                  key={i}
                  onClick={() => {
                    setInput(s);
                    inputRef.current?.focus();
                  }}
                  className="rounded-lg border bg-card px-4 py-3 text-left text-sm text-muted-foreground transition-colors hover:border-primary/50 hover:text-foreground"
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Chat messages */}
        {messages.map((msg, i) => (
          <div
            key={i}
            className={`flex gap-3 ${msg.role === "user" ? "justify-end" : "justify-start"}`}
          >
            {msg.role === "assistant" && (
              <div className="mt-1 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary/10">
                <Bot className="h-4 w-4 text-primary" />
              </div>
            )}
            <div
              className={`max-w-3xl rounded-lg px-4 py-3 ${
                msg.role === "user"
                  ? "bg-primary/10 border border-primary/20 text-foreground"
                  : "bg-card border text-foreground"
              }`}
            >
              {/* Markdown content */}
              <div className="prose prose-sm dark:prose-invert max-w-none break-words text-sm leading-relaxed">
                <ReactMarkdown
                  remarkPlugins={[remarkGfm]}
                  components={{
                    h1: ({ children }) => (
                      <h1 className="mb-2 mt-4 text-xl font-bold">{children}</h1>
                    ),
                    h2: ({ children }) => (
                      <h2 className="mb-2 mt-3 text-lg font-bold">{children}</h2>
                    ),
                    h3: ({ children }) => (
                      <h3 className="mb-1 mt-3 text-base font-semibold">{children}</h3>
                    ),
                    p: ({ children }) => (
                      <p className="mb-2 text-foreground/90">{children}</p>
                    ),
                    strong: ({ children }) => (
                      <strong className="font-semibold text-foreground">{children}</strong>
                    ),
                    code: ({ children, className }) => {
                      const isBlock = className?.includes("language-");
                      if (isBlock) {
                        return <code className="text-xs">{children}</code>;
                      }
                      return (
                        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs text-primary">
                          {children}
                        </code>
                      );
                    },
                    pre: ({ children }) => (
                      <pre className="my-2 overflow-x-auto rounded-lg bg-muted p-3 font-mono text-xs">
                        {children}
                      </pre>
                    ),
                    table: ({ children }) => (
                      <div className="my-2 overflow-x-auto">
                        <table className="w-full text-xs">{children}</table>
                      </div>
                    ),
                    thead: ({ children }) => (
                      <thead className="bg-muted">{children}</thead>
                    ),
                    th: ({ children }) => (
                      <th className="border-b px-3 py-2 text-left text-[10px] font-semibold uppercase text-primary">
                        {children}
                      </th>
                    ),
                    td: ({ children }) => (
                      <td className="border-b border-border/50 px-3 py-1.5 text-foreground/80">
                        {children}
                      </td>
                    ),
                    ul: ({ children }) => (
                      <ul className="mb-2 list-inside list-disc space-y-1">{children}</ul>
                    ),
                    ol: ({ children }) => (
                      <ol className="mb-2 list-inside list-decimal space-y-1">{children}</ol>
                    ),
                    li: ({ children }) => <li>{children}</li>,
                    a: ({ href, children }) => (
                      <a
                        href={href}
                        className="text-primary hover:underline"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        {children}
                      </a>
                    ),
                    blockquote: ({ children }) => (
                      <blockquote className="my-2 border-l-2 border-primary pl-3 italic text-muted-foreground">
                        {children}
                      </blockquote>
                    ),
                    hr: () => <hr className="my-3 border-border" />,
                  }}
                >
                  {msg.content}
                </ReactMarkdown>
              </div>

              {/* Action approval cards (hybrid model) */}
              {msg.actions &&
                msg.actions.length > 0 &&
                msg.actions.map((action, j) => (
                  <ActionCard key={j} action={action} onApprove={handleApprove} />
                ))}

              {/* Model badge */}
              {msg.role === "assistant" && msg.model && (
                <div className="mt-2 text-right font-mono text-[10px] text-muted-foreground">
                  {msg.model}
                </div>
              )}
            </div>
            {msg.role === "user" && (
              <div className="mt-1 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-secondary">
                <User className="h-4 w-4 text-secondary-foreground" />
              </div>
            )}
          </div>
        ))}

        {/* Loading indicator */}
        {chatMutation.isPending && (
          <div className="flex gap-3">
            <div className="mt-1 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary/10">
              <Bot className="h-4 w-4 text-primary" />
            </div>
            <div className="rounded-lg border bg-card px-4 py-3">
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <Loader2 className="h-4 w-4 animate-spin" />
                {isKo
                  ? "GPU 가격 조회 및 응답 생성 중..."
                  : "Querying GPU prices & generating response..."}
              </div>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input area */}
      <div className="border-t bg-card p-4">
        <div className="mx-auto flex max-w-4xl items-end gap-3">
          <div className="relative flex-1">
            <textarea
              ref={inputRef}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={
                isKo
                  ? "GPU 작업에 대해 질문하세요... (Shift+Enter: 줄바꿈)"
                  : "Ask about GPU jobs... (Shift+Enter for new line)"
              }
              rows={1}
              className="w-full resize-none rounded-lg border bg-background px-4 py-2.5 text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/50"
              style={{ minHeight: 42, maxHeight: 120 }}
              onInput={(e) => {
                const el = e.target as HTMLTextAreaElement;
                el.style.height = "auto";
                el.style.height = Math.min(el.scrollHeight, 120) + "px";
              }}
            />
          </div>
          <Button
            onClick={sendMessage}
            disabled={!input.trim() || chatMutation.isPending}
            size="icon"
            className="shrink-0"
          >
            <Send className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </div>
  );
}

/* ── Action approval card (hybrid model) ────────────────────── */
function ActionCard({
  action,
  onApprove,
}: {
  action: ProposedAction;
  onApprove: (a: ProposedAction) => void;
}) {
  const [status, setStatus] = useState<"pending" | "approved" | "denied">("pending");

  return (
    <div className="mt-3 rounded-lg border-2 border-dashed border-primary/30 bg-primary/5 p-4">
      <div className="mb-2 flex items-center gap-2 text-sm font-semibold">
        <Cpu className="h-4 w-4 text-primary" />
        GPU 작업 제안
      </div>
      <div className="mb-3 grid grid-cols-2 gap-x-4 gap-y-1 text-xs text-muted-foreground">
        {action.instance_type && (
          <>
            <span>Instance</span>
            <span className="font-medium text-foreground">{action.instance_type}</span>
          </>
        )}
        {action.region && (
          <>
            <span>Region</span>
            <span className="font-medium text-foreground">{action.region}</span>
          </>
        )}
        {action.gpu_count && (
          <>
            <span>GPU Count</span>
            <span className="font-medium text-foreground">{action.gpu_count}</span>
          </>
        )}
        {action.image && (
          <>
            <span>Image</span>
            <span className="truncate font-medium text-foreground">{action.image}</span>
          </>
        )}
        {action.reason && (
          <>
            <span>Reason</span>
            <span className="font-medium text-foreground">{action.reason}</span>
          </>
        )}
      </div>

      {status === "pending" && (
        <div className="flex gap-2">
          <Button
            size="sm"
            onClick={() => {
              setStatus("approved");
              onApprove(action);
            }}
          >
            <CheckCircle2 className="mr-1 h-3 w-3" />
            승인
          </Button>
          <Button
            size="sm"
            variant="outline"
            onClick={() => setStatus("denied")}
          >
            <XCircle className="mr-1 h-3 w-3" />
            거부
          </Button>
        </div>
      )}
      {status === "approved" && (
        <div className="flex items-center gap-1 text-sm text-green-600 dark:text-green-400">
          <CheckCircle2 className="h-4 w-4" /> 승인됨 — 작업이 대기열에 추가되었습니다
        </div>
      )}
      {status === "denied" && (
        <div className="flex items-center gap-1 text-sm text-muted-foreground">
          <XCircle className="h-4 w-4" /> 거부됨
        </div>
      )}
    </div>
  );
}
