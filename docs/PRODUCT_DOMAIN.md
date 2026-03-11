# Auto-my-invoice 프로덕트 도메인 문서

## 1. 제품 정의

**Auto-my-invoice**는 프리랜서와 소규모 사업자를 위한 **송장 자동화 SaaS**이다.
송장을 업로드하면 AI가 데이터를 추출하고, 미수금 리마인더를 자동 발송하며, 결제까지 하나의 흐름으로 연결한다.

**핵심 가치**: "돈 받는 일에 쓰는 시간을 0에 가깝게 줄인다"

---

## 2. 도메인 모델 (Bounded Contexts)

Auto-my-invoice는 7개의 도메인 컨텍스트로 구성된다.

```
┌─────────────────────────────────────────────────────────┐
│                    사용자 요청 흐름                        │
│                                                         │
│  ① Upload PDF ──→ ② AI Extraction ──→ ③ Create Invoice  │
│                                           │             │
│                                           ▼             │
│                                     ④ Send Invoice      │
│                                           │             │
│                              ┌────────────┼──────────┐  │
│                              ▼            ▼          ▼  │
│                        ⑤ Schedule    ⑥ Payment    ⑦ Track│
│                        Reminders     Link         Status│
│                              │            │             │
│                              ▼            ▼             │
│                        Auto Email    Paddle Pay         │
│                              │            │             │
│                              └────────┬───┘             │
│                                       ▼                 │
│                              ⑧ Payment Received         │
│                                       │                 │
│                              ┌────────┼────────┐        │
│                              ▼                 ▼        │
│                        Cancel            Update         │
│                        Reminders         Status→Paid    │
└─────────────────────────────────────────────────────────┘
```

---

## 3. 컨텍스트 상세

### 3.1 Accounts (사용자 인증 및 권한)

**모듈**: `AutoMyInvoice.Accounts`
**책임**: 사용자 등록, 인증, OAuth, 세션 관리, 플랜 기반 권한 제어

| 개념 | 설명 |
|------|------|
| User | 서비스 사용자. email/password 또는 Google OAuth로 가입 |
| UserToken | 세션 토큰. 로그인 상태 유지에 사용 |
| Plan | 사용자의 구독 플랜 (`free`, `starter`, `pro`) |

**핵심 규칙**:
- Free 플랜은 **월 3건** 송장 생성 제한
- Starter/Pro는 **무제한**
- 플랜별 기능 게이팅:
  - `free`: 기본 CRUD + 템플릿
  - `starter`: + AI 리마인더, Paddle 결제, 분석
  - `pro`: + 팀, 커스텀 브랜딩, API 접근

**엔티티 관계**:
```
User ──1:N──→ Invoice
User ──1:N──→ Client
User ──1:N──→ Subscription
```

---

### 3.2 Clients (클라이언트 관리)

**모듈**: `AutoMyInvoice.Clients`
**책임**: 송장을 받는 거래처(클라이언트) 정보 관리

| 개념 | 설명 |
|------|------|
| Client | 송장 수신자. 이름, 이메일, 회사명, 타임존 보유 |

**핵심 규칙**:
- 클라이언트는 사용자(User)에 종속 (멀티테넌시)
- 이름, 이메일, 회사명으로 검색 가능
- AI 추출 시 이메일 기준으로 기존 클라이언트 매칭 시도
- 타임존은 리마인더 발송 시간 계산에 사용

---

### 3.3 Invoices (송장 관리) — 핵심 도메인

**모듈**: `AutoMyInvoice.Invoices`
**책임**: 송장 생명주기 관리, 상태 전환, 집계, 발송

| 개념 | 설명 |
|------|------|
| Invoice | 송장. 금액, 마감일, 상태, 클라이언트 참조 |
| InvoiceItem | 송장 항목. 설명, 수량, 단가 |

**송장 상태 머신**:
```
          create           send              D+1 past due
 ┌─────┐ ──────→ ┌───────┐ ──────→ ┌──────┐ ──────────→ ┌─────────┐
 │ NEW │         │ DRAFT │         │ SENT │              │ OVERDUE │
 └─────┘         └───────┘         └──────┘              └─────────┘
                     │                 │                      │
                     │ delete          │ pay                  │ pay
                     ▼                 ▼                      ▼
                 ┌─────────┐     ┌────────┐             ┌────────┐
                 │ DELETED │     │  PAID  │             │  PAID  │
                 └─────────┘     └────────┘             └────────┘
```

**유효 상태값**: `draft`, `sent`, `overdue`, `paid`, `partially_paid`

**핵심 규칙**:
- 송장 생성 시 플랜 한도 체크 (`Accounts.can_create_invoice?/1`)
- `draft` 상태에서만 삭제 가능
- `send_invoice/1` 실행 시 연쇄 동작:
  1. 상태를 `sent`로 변경 + `sent_at` 기록
  2. Paddle 결제 링크 자동 생성
  3. 3단계 리마인더 자동 예약
  4. 클라이언트에게 송장 이메일 발송
- `mark_as_paid/1` 실행 시:
  1. 상태를 `paid`로 변경 + `paid_at` 기록
  2. 예약된 리마인더 자동 취소
  3. PubSub으로 실시간 업데이트 브로드캐스트

**집계 함수**:
| 함수 | 용도 |
|------|------|
| `count_by_status/1` | 대시보드 상태별 카운트 |
| `total_outstanding/1` | 미수금 총액 + 연체 건수 |
| `collection_rate/1` | 수금률 (%) |
| `collected_this_month/1` | 이번 달 수금액 |
| `recent_invoices/2` | 최근 송장 목록 |
| `outstanding_summary/1` | 미수금 요약 (총액, 건수, 연체액) |

---

### 3.4 Extraction (AI OCR 추출)

**모듈**: `AutoMyInvoice.Extraction`
**책임**: PDF 송장에서 AI로 데이터 자동 추출

| 개념 | 설명 |
|------|------|
| ExtractionJob | 추출 작업. 상태, 원본 응답, 추출 결과, 신뢰도 보유 |

**추출 파이프라인**:
```
PDF 업로드 → ExtractionJob 생성(pending)
          → Oban Worker 큐잉
          → AI Vision API 호출(processing)
          → 결과 파싱 + 저장(completed / failed)
          → PubSub 알림 → UI 실시간 반영
```

**AI가 추출하는 데이터**:
| 필드 | 설명 |
|------|------|
| `amount` | 총 금액 |
| `currency` | 통화 코드 |
| `due_date` | 결제 마감일 |
| `client_name` | 클라이언트 이름 |
| `client_email` | 클라이언트 이메일 |
| `client_company` | 클라이언트 회사 |
| `items[]` | 항목별 설명, 수량, 단가 |
| `notes` | 비고 |

**클라이언트 매칭 로직**:
- 추출된 이메일로 기존 클라이언트 검색
- 존재하면 → `{:existing, client}` (자동 연결)
- 없으면 → `{:suggested, %{name, email, company}}` (신규 생성 제안)

---

### 3.5 Reminders (자동 리마인더)

**모듈**: `AutoMyInvoice.Reminders`
**책임**: 3단계 에스컬레이션 리마인더 스케줄링, 발송, 추적

| 개념 | 설명 |
|------|------|
| Reminder | 리마인더 레코드. 단계, 예약 시간, 발송 상태, 열람/클릭 추적 |

**3단계 에스컬레이션**:

| 단계 | 시점 | 톤 | 목적 |
|------|------|------|------|
| Step 1 | 마감일 + 1일 | 친근 | "확인 부탁드립니다" |
| Step 2 | 마감일 + 7일 | 부드러운 독촉 | "마감이 지났습니다" |
| Step 3 | 마감일 + 14일 | 경고 | "최종 안내드립니다" |

**스케줄링 규칙**:
- 클라이언트 타임존 기준 오전 9~10시에 발송 (무작위 분 배정)
- 주말(토/일) 자동 건너뜀 → 다음 평일로 이동
- Oban Worker로 비동기 실행

**자동 취소**:
- 결제 완료(`mark_as_paid`) 시 예약된 리마인더 일괄 취소
- Oban Job도 함께 취소

**이메일 추적**:
| 지표 | 방식 |
|------|------|
| 열람 (Open) | 1x1 투명 GIF 픽셀 삽입 |
| 클릭 (Click) | 결제 링크 리디렉트 추적 |

추적 데이터: `open_count`, `opened_at`, `click_count`, `clicked_at`

**분석 함수**:
- `reminder_stats/1`: 단계별 발송/열람/클릭 수, 오픈율, 클릭률

---

### 3.6 Payments (결제 처리)

**모듈**: `AutoMyInvoice.Payments`
**책임**: Paddle Webhook 처리, 결제 기록, 이벤트 로깅

| 개념 | 설명 |
|------|------|
| Payment | 결제 레코드. Paddle 트랜잭션 ID, 금액, 상태 |
| PaddleWebhookEvent | Webhook 수신 로그. 멱등성 보장용 |

**결제 흐름 (Paddle Webhook)**:
```
클라이언트가 이메일 내 결제 링크 클릭
  → Paddle 결제 페이지에서 결제
  → Paddle이 transaction.completed Webhook 발송
  → Auto-my-invoice 수신:
    1. Webhook 이벤트 로그 (중복 방지)
    2. Payment 레코드 생성
    3. Invoice를 paid로 전환
    4. 리마인더 자동 취소
    5. PubSub으로 실시간 UI 업데이트
```

**Webhook 멱등성**:
- `event_id` 기준 중복 체크
- 처리 완료/실패 상태 기록 (`processed_at`, `error_message`)

---

### 3.7 Billing (구독 관리)

**모듈**: `AutoMyInvoice.Billing`
**책임**: Paddle 기반 SaaS 구독 플랜 관리

| 개념 | 설명 |
|------|------|
| Subscription | 구독 레코드. Paddle 구독 ID, 상태, 결제 주기 |

**구독 플랜**:

| 플랜 | 가격 | 월 송장 한도 | 핵심 기능 |
|------|------|------|------|
| Free | $0 | 3건 | CRUD + 기본 템플릿 |
| Starter | $9/월 | 무제한 | + AI 리마인더, Paddle 결제, 분석 |
| Pro | $29/월 | 무제한 | + 팀, 커스텀 브랜딩, API |

**구독 상태 전환 (Paddle Webhook)**:
```
subscription.activated  → activate_subscription → User.plan 업데이트
subscription.updated    → update_subscription   → 결제 주기 갱신
subscription.canceled   → cancel_subscription   → 상태 cancelled
```

---

## 4. 컨텍스트 간 의존 관계

```
                    ┌──────────┐
                    │ Accounts │ (인증, 권한, 플랜)
                    └────┬─────┘
                         │ User 참조
            ┌────────────┼────────────┐
            ▼            ▼            ▼
      ┌─────────┐  ┌──────────┐  ┌─────────┐
      │ Clients │  │ Invoices │  │ Billing │
      └────┬────┘  └────┬─────┘  └─────────┘
           │            │
           │ client_id  │ invoice_id
           ▼            ├──────────────┐
      ┌──────────┐      ▼              ▼
      │Extraction│  ┌──────────┐  ┌──────────┐
      └──────────┘  │Reminders │  │ Payments │
                    └──────────┘  └──────────┘
```

**의존 방향 규칙**:
- `Invoices` → `Accounts` (플랜 체크), `Clients` (preload), `Reminders` (스케줄링/취소), `Payments` (Paddle 링크)
- `Payments` → `Invoices` (상태 변경)
- `Reminders` → 독립 (invoice_id로만 연결)
- `Extraction` → `Clients` (매칭), `Invoices` (데이터 변환)
- `Billing` → `Accounts` (플랜 업데이트)

---

## 5. 인프라 컴포넌트

### 5.1 비동기 작업 (Oban Workers)

| Worker | 스케줄 | 역할 |
|--------|--------|------|
| `ReminderWorker` | 예약 시간 | 개별 리마인더 이메일 발송 |
| `ReminderScheduler` | 매시간 Cron | 연체 송장 스캔 + 리마인더 재스케줄 |
| `OcrExtractionWorker` | 즉시 | PDF → AI Vision API → 데이터 추출 |

### 5.2 실시간 통신 (PubSub)

| 토픽 | 이벤트 | 용도 |
|------|--------|------|
| `user:{id}:invoices` | `:invoice_updated` | 대시보드 실시간 갱신 |
| `payment:{invoice_id}` | `:payment_received` | 결제 완료 알림 |
| `extraction:{job_id}` | `:extraction_completed` | OCR 완료 → UI 반영 |

### 5.3 이메일 시스템 (Swoosh)

| 이메일 | 트리거 | 수신자 |
|--------|--------|--------|
| 송장 발송 메일 | `send_invoice/1` | 클라이언트 |
| 리마인더 Step 1~3 | Oban ReminderWorker | 클라이언트 |

### 5.4 외부 서비스 연동

| 서비스 | 용도 | 연동 방식 |
|--------|------|-----------|
| Paddle | 결제 + 구독 | Webhook + API |
| OpenAI Vision | PDF OCR 추출 | REST API |
| Fly.io | 배포 + 호스팅 | CLI + fly.toml |

---

## 6. 데이터 모델 요약

```
users
  ├── id (uuid, PK)
  ├── email, name, company_name
  ├── plan ("free" | "starter" | "pro")
  ├── google_uid (OAuth)
  └── paddle_customer_id

clients
  ├── id (uuid, PK)
  ├── user_id (FK → users)
  ├── name, email, company, phone
  └── timezone

invoices
  ├── id (uuid, PK)
  ├── user_id (FK → users)
  ├── client_id (FK → clients)
  ├── invoice_number, amount, currency
  ├── status ("draft"|"sent"|"overdue"|"paid"|"partially_paid")
  ├── due_date, sent_at, paid_at
  ├── paid_amount, paddle_payment_link
  └── notes

invoice_items
  ├── id (uuid, PK)
  ├── invoice_id (FK → invoices)
  ├── description, quantity, unit_price
  └── position

reminders
  ├── id (uuid, PK)
  ├── invoice_id (FK → invoices)
  ├── step (1 | 2 | 3)
  ├── status ("scheduled"|"pending"|"sent"|"cancelled")
  ├── scheduled_at, sent_at
  ├── open_count, opened_at
  ├── click_count, clicked_at
  └── oban_job_id

payments
  ├── id (uuid, PK)
  ├── invoice_id (FK → invoices)
  ├── paddle_transaction_id
  ├── amount, currency, status
  ├── paid_at
  └── raw_webhook (jsonb)

paddle_webhook_events
  ├── id (uuid, PK)
  ├── event_id (unique, 멱등성)
  ├── event_type, payload (jsonb)
  ├── processed_at
  └── error_message

extraction_jobs
  ├── id (uuid, PK)
  ├── user_id (FK → users)
  ├── status ("pending"|"processing"|"completed"|"failed")
  ├── file_path, file_name
  ├── raw_response, extracted_data (jsonb)
  ├── confidence_score
  └── processing_started_at, processing_completed_at

subscriptions
  ├── id (uuid, PK)
  ├── user_id (FK → users)
  ├── paddle_subscription_id, paddle_customer_id
  ├── plan, status
  ├── current_period_start, current_period_end
  └── cancelled_at
```

---

## 7. 핵심 비즈니스 플로우

### 7.1 송장 업로드 → 결제 완료 (Happy Path)

```
1. 사용자가 PDF 드래그 앤 드롭 업로드
2. ExtractionJob 생성 → OcrExtractionWorker 큐잉
3. AI Vision API가 금액, 마감일, 클라이언트 정보 추출
4. 추출 완료 → PubSub → Upload UI에 결과 표시
5. 사용자가 확인/수정 후 송장 생성
6. "Send" 클릭 → Invoices.send_invoice/1 실행:
   a. 상태 → sent
   b. Paddle 결제 링크 생성
   c. 3단계 리마인더 예약 (D+1, D+7, D+14)
   d. 클라이언트에게 송장 이메일 발송
7. [D+1] ReminderWorker가 Step 1 이메일 발송
8. 클라이언트가 이메일 내 "Pay Now" 클릭
9. EmailTrackingController가 클릭 기록 → Paddle 결제 페이지로 리디렉트
10. 클라이언트가 결제 완료
11. Paddle Webhook → Payments.process_transaction_completed/1:
    a. Payment 레코드 생성
    b. Invoice → paid 상태
    c. Step 2, 3 리마인더 자동 취소
    d. PubSub → 대시보드 실시간 반영
```

### 7.2 미결제 에스컬레이션 (Unhappy Path)

```
1. [D+1] Step 1 리마인더 발송 → 반응 없음
2. [D+7] Step 2 리마인더 발송 → 클라이언트가 열람 (Open 추적)
3. [D+14] Step 3 최종 경고 발송
4. 이후 → 사용자가 수동 대응 (향후 추심 연동 가능)
```

---

## 8. 기술 스택과 도메인 매핑

| 도메인 요구사항 | 기술 선택 | 이유 |
|----------------|-----------|------|
| 실시간 대시보드 | Phoenix LiveView + PubSub | 별도 JS 프레임워크 없이 실시간 UI |
| 비동기 리마인더 | Oban (PostgreSQL 기반) | Redis 불필요, 재시도/스케줄링 내장 |
| 대량 동시 접속 | BEAM VM 경량 프로세스 | WebSocket 연결 수천 개 안정 처리 |
| 장애 복구 | OTP Supervisor | 이메일 발송 실패 시 자동 재시도 |
| 결제 연동 | Paddle Webhook | 결제 → 상태 업데이트 자동화 |
| AI OCR | OpenAI Vision API | PDF에서 구조화된 데이터 추출 |

---

## 9. 용어 사전 (Ubiquitous Language)

| 용어 | 정의 |
|------|------|
| **송장 (Invoice)** | 클라이언트에게 보내는 대금 청구서 |
| **클라이언트 (Client)** | 송장을 받는 거래처/고객 |
| **리마인더 (Reminder)** | 미결제 송장에 대한 자동 독촉 이메일 |
| **에스컬레이션 (Escalation)** | 시간 경과에 따라 리마인더 톤이 강해지는 3단계 구조 |
| **추출 (Extraction)** | AI가 PDF에서 송장 데이터를 자동으로 읽어내는 과정 |
| **결제 링크 (Payment Link)** | Paddle을 통해 생성된 즉시 결제 URL |
| **미수금 (Outstanding)** | 발송했지만 아직 결제되지 않은 송장 금액 |
| **수금률 (Collection Rate)** | 전체 송장 대비 수금 완료된 비율 (%) |
| **플랜 게이팅 (Plan Gating)** | 구독 플랜에 따라 기능 접근을 제한하는 메커니즘 |
| **멱등성 (Idempotency)** | 같은 Webhook을 여러 번 받아도 결과가 동일한 특성 |
| **Oban Job** | PostgreSQL 기반 비동기 작업 큐의 개별 작업 단위 |
