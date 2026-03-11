# Auto-my-invoice API 명세서

> 기술 참조 문서. OpenAPI 3.1 스펙(`packages/api-spec/openapi.yaml`)과 동기화됩니다.

---

## 1. 기본 정보

| 항목 | 값 |
|------|------|
| Base URL (Dev) | `http://localhost:4000/api/v1` |
| Base URL (Prod) | `https://api.automyinvoice.app/api/v1` |
| 인증 방식 | Bearer Token (`Authorization: Bearer <token>`) |
| 컨텐츠 타입 | `application/json` (업로드: `multipart/form-data`) |
| 에러 형식 | `{ "error": { "code": "...", "message": "...", "details": {} } }` |

---

## 2. 인증 (Auth)

### POST /auth/register
신규 회원가입

**Request**:
```json
{
  "email": "user@example.com",
  "password": "securepass123",
  "name": "홍길동"
}
```

**Response** `201 Created`:
```json
{
  "data": {
    "access_token": "eyJhbGci...",
    "refresh_token": "dGhpcyBp...",
    "expires_in": 3600,
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "name": "홍길동",
      "plan": "free"
    }
  }
}
```

**에러**: `422` 이메일 중복, 비밀번호 8자 미만

---

### POST /auth/login
이메일/비밀번호 로그인

**Request**:
```json
{
  "email": "user@example.com",
  "password": "securepass123"
}
```

**Response** `200 OK`: AuthResponse (위와 동일)
**에러**: `401` 이메일/비밀번호 불일치

---

### POST /auth/google
Google OAuth 로그인

**Request**:
```json
{
  "id_token": "Google ID token from client SDK"
}
```

**Response** `200 OK`: AuthResponse
**에러**: `401` 유효하지 않은 토큰

---

### POST /auth/refresh 🔒
토큰 갱신

**Request**:
```json
{
  "refresh_token": "dGhpcyBp..."
}
```

**Response** `200 OK`: AuthResponse (새 토큰)
**에러**: `401` 만료/무효 토큰

---

### DELETE /auth/logout 🔒
세션 무효화

**Response** `204 No Content`

---

## 3. 대시보드 (Dashboard)

### GET /dashboard 🔒
KPI 요약 데이터

**Query Parameters**:
| 파라미터 | 타입 | 기본값 | 설명 |
|----------|------|--------|------|
| period | string | month | `month`, `quarter`, `year` |

**Response** `200 OK`:
```json
{
  "data": {
    "total_outstanding": 5250000,
    "overdue_count": 2,
    "collection_rate": 73,
    "collected_this_month": 3500000,
    "active_reminders": 5,
    "status_counts": {
      "all": 12,
      "draft": 2,
      "sent": 4,
      "overdue": 2,
      "paid": 4
    },
    "currency": "KRW"
  }
}
```

---

### GET /dashboard/recent 🔒
최근 송장 목록

**Query Parameters**:
| 파라미터 | 타입 | 기본값 | 설명 |
|----------|------|--------|------|
| limit | integer | 5 | 최대 20 |

**Response** `200 OK`:
```json
{
  "data": [
    {
      "id": "uuid",
      "invoice_number": "INV-2026-0042",
      "status": "sent",
      "amount": 3500000,
      "currency": "KRW",
      "due_date": "2026-04-01",
      "client": { "id": "uuid", "name": "ABC Corp" }
    }
  ]
}
```

---

## 4. 송장 (Invoices)

### GET /invoices 🔒
송장 목록 조회

**Query Parameters**:
| 파라미터 | 타입 | 기본값 | 설명 |
|----------|------|--------|------|
| page | integer | 1 | 페이지 번호 |
| limit | integer | 20 | 페이지 크기 (최대 100) |
| status | string | - | `draft`, `sent`, `overdue`, `paid` |
| client_id | uuid | - | 특정 클라이언트 필터 |
| search | string | - | 송장번호, 클라이언트명, 메모 검색 |
| sort_by | string | due_date | `due_date`, `amount`, `inserted_at` |
| sort_order | string | desc | `asc`, `desc` |

**Response** `200 OK`:
```json
{
  "data": [
    {
      "id": "uuid",
      "invoice_number": "INV-2026-0042",
      "status": "sent",
      "amount": "3500000.00",
      "paid_amount": "0.00",
      "currency": "KRW",
      "due_date": "2026-04-01",
      "sent_at": "2026-03-10T09:00:00Z",
      "paid_at": null,
      "paddle_payment_link": "https://pay.paddle.com/...",
      "notes": "디자인 작업 3차분",
      "client": {
        "id": "uuid",
        "name": "ABC Corp",
        "email": "billing@abc.com"
      },
      "items": [
        {
          "id": "uuid",
          "description": "UI 디자인",
          "quantity": "1.00",
          "unit_price": "3500000.00",
          "position": 0
        }
      ],
      "inserted_at": "2026-03-10T08:30:00Z",
      "updated_at": "2026-03-10T09:00:00Z"
    }
  ],
  "meta": {
    "total": 12,
    "page": 1,
    "limit": 20,
    "total_pages": 1
  }
}
```

---

### POST /invoices 🔒
송장 생성

**Request**:
```json
{
  "client_id": "uuid",
  "invoice_number": "INV-2026-0042",
  "amount": "3500000.00",
  "currency": "KRW",
  "due_date": "2026-04-01",
  "notes": "디자인 작업 3차분",
  "items": [
    {
      "description": "UI 디자인",
      "quantity": "1",
      "unit_price": "3500000.00",
      "position": 0
    }
  ]
}
```

**Response** `201 Created`: Invoice 객체
**에러**:
- `422` 유효성 검증 실패
- `422` `{ "code": "plan_limit", "message": "월 송장 한도(3건)를 초과했습니다" }`

---

### GET /invoices/:id 🔒
송장 상세 조회

**Response** `200 OK`: Invoice 객체 (client, items preload)
**에러**: `404` 존재하지 않음

---

### PUT /invoices/:id 🔒
송장 수정 (draft 상태만)

**Request**: 변경할 필드만 전송
**Response** `200 OK`: 수정된 Invoice 객체
**에러**: `404`, `422` (draft가 아닌 경우)

---

### DELETE /invoices/:id 🔒
송장 삭제 (draft 상태만)

**Response** `204 No Content`
**에러**: `404`, `422` `{ "code": "cannot_delete", "message": "draft 상태의 송장만 삭제 가능합니다" }`

---

### POST /invoices/:id/send 🔒
송장 발송 (핵심 액션)

이메일 발송 + Paddle 결제 링크 생성 + 3단계 리마인더 예약을 원스톱으로 실행합니다.

**Request** (선택):
```json
{
  "message": "작업 완료 후 송장 전달드립니다."
}
```

**Response** `200 OK`: 발송된 Invoice 객체 (status: "sent")

**연쇄 동작**:
1. 상태 → `sent`, `sent_at` 기록
2. Paddle 결제 링크 생성 → `paddle_payment_link` 저장
3. 리마인더 3건 예약 (D+1, D+7, D+14)
4. 클라이언트에게 송장 이메일 발송

**에러**: `422` draft가 아닌 경우 (`not_draft`)

---

### POST /invoices/:id/mark_paid 🔒
결제 완료 수동 처리

**Request** (선택):
```json
{
  "paid_at": "2026-03-15T10:30:00Z",
  "payment_method": "bank_transfer",
  "payment_reference": "이체확인번호-12345"
}
```

**Response** `200 OK`: paid 상태 Invoice 객체

**연쇄 동작**:
1. 상태 → `paid`, `paid_at` 기록
2. 예약된 리마인더 전부 취소

---

## 5. 클라이언트 (Clients)

### GET /clients 🔒
클라이언트 목록 조회

**Query Parameters**:
| 파라미터 | 타입 | 기본값 | 설명 |
|----------|------|--------|------|
| page | integer | 1 | 페이지 번호 |
| limit | integer | 20 | 페이지 크기 |
| q | string | - | 이름/이메일/회사명 검색 |
| sort_by | string | name | `name`, `email`, `inserted_at` |
| sort_order | string | asc | `asc`, `desc` |

**Response** `200 OK`:
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "ABC Corp",
      "email": "billing@abc.com",
      "company": "ABC Corporation",
      "phone": "02-1234-5678",
      "timezone": "Asia/Seoul",
      "inserted_at": "2026-03-01T00:00:00Z"
    }
  ],
  "meta": { "total": 5, "page": 1, "limit": 20, "total_pages": 1 }
}
```

---

### POST /clients 🔒
클라이언트 생성

**Request**:
```json
{
  "name": "ABC Corp",
  "email": "billing@abc.com",
  "company": "ABC Corporation",
  "phone": "02-1234-5678",
  "timezone": "Asia/Seoul"
}
```

**Response** `201 Created`: Client 객체
**에러**: `422` name 누락

---

### GET /clients/:id 🔒
클라이언트 상세

**Response** `200 OK`: Client 객체
**에러**: `404`

---

### PUT /clients/:id 🔒
클라이언트 수정

**Request**: 변경할 필드만 전송
**Response** `200 OK`: 수정된 Client 객체

---

### DELETE /clients/:id 🔒
클라이언트 삭제

**Response** `204 No Content`
**에러**: `404`

---

## 6. 업로드 & AI 추출 (Upload)

### POST /upload 🔒
PDF 업로드 및 OCR 추출 시작

**Request**: `multipart/form-data`
| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| file | binary | ✅ | PDF 파일 (최대 10MB) |

**Response** `202 Accepted`:
```json
{
  "data": {
    "id": "uuid",
    "status": "pending",
    "file_name": "invoice-march.pdf",
    "inserted_at": "2026-03-10T08:00:00Z"
  }
}
```

**에러**: `422` 파일 없음/형식 오류/용량 초과

---

### GET /extraction/:id 🔒
추출 작업 상태 조회 (폴링)

**Response** `200 OK`:

상태별 응답:

**pending/processing**:
```json
{
  "data": {
    "id": "uuid",
    "status": "processing",
    "file_name": "invoice-march.pdf"
  }
}
```

**completed**:
```json
{
  "data": {
    "id": "uuid",
    "status": "completed",
    "file_name": "invoice-march.pdf",
    "confidence_score": 0.95,
    "extracted_data": {
      "amount": "3500000",
      "currency": "KRW",
      "due_date": "2026-04-01",
      "client_name": "ABC Corp",
      "client_email": "billing@abc.com",
      "client_company": "ABC Corporation",
      "items": [
        {
          "description": "UI 디자인",
          "quantity": "1",
          "unit_price": "3500000"
        }
      ],
      "notes": "3차 작업분"
    },
    "client_match": {
      "type": "existing",
      "client": { "id": "uuid", "name": "ABC Corp" }
    }
  }
}
```

**failed**:
```json
{
  "data": {
    "id": "uuid",
    "status": "failed",
    "error_message": "PDF 파일을 읽을 수 없습니다"
  }
}
```

---

## 7. 설정 (Settings)

### GET /settings 🔒
현재 사용자 설정 조회

**Response** `200 OK`:
```json
{
  "data": {
    "name": "홍길동",
    "email": "user@example.com",
    "company_name": "길동 디자인",
    "plan": "starter",
    "default_currency": "KRW",
    "invoice_prefix": "INV",
    "payment_terms_days": 30
  }
}
```

---

### PUT /settings 🔒
설정 업데이트

**Request**: 변경할 필드만 전송
```json
{
  "company_name": "길동 스튜디오",
  "default_currency": "USD"
}
```

**Response** `200 OK`: 수정된 Settings 객체

---

## 8. Webhook (서버 간 통신)

### POST /api/webhooks/paddle
Paddle Webhook 수신 (인증 불필요, Paddle 서명 검증)

**처리하는 이벤트**:

| 이벤트 | 동작 |
|--------|------|
| `transaction.completed` | Payment 생성 → Invoice paid → 리마인더 취소 |
| `subscription.activated` | 구독 활성화 → User 플랜 업그레이드 |
| `subscription.updated` | 구독 갱신 → 결제 주기 업데이트 |
| `subscription.canceled` | 구독 취소 처리 |

**멱등성**: `event_id` 기준 중복 이벤트 무시

---

## 9. 이메일 추적 (공개 엔드포인트)

### GET /api/track/open/:reminder_id
이메일 열람 추적 (투명 1x1 GIF 반환)

- 이메일 클라이언트가 이미지 로드 시 자동 호출
- `open_count` 증가, 최초 열람 시 `opened_at` 기록
- 응답: 1x1 투명 GIF (`image/gif`)

---

### GET /api/track/click/:reminder_id
결제 링크 클릭 추적

- `click_count` 증가, 최초 클릭 시 `clicked_at` 기록
- 응답: `302 Redirect` → Paddle 결제 링크
- 결제 링크 없는 경우: `404`

---

## 10. 에러 코드

| HTTP | code | 설명 |
|------|------|------|
| 401 | `unauthorized` | 인증 필요 또는 토큰 만료 |
| 403 | `forbidden` | 권한 없음 (다른 사용자의 리소스) |
| 404 | `not_found` | 리소스 없음 |
| 422 | `validation_failed` | 입력값 유효성 실패 |
| 422 | `plan_limit` | Free 플랜 월 3건 한도 초과 |
| 422 | `not_draft` | draft가 아닌 송장 발송/수정/삭제 시도 |
| 422 | `cannot_delete` | 삭제 불가 상태 |
| 429 | `rate_limited` | 요청 과다 (향후) |
| 500 | `internal_error` | 서버 내부 오류 |

---

## 11. 인증 흐름

```
[회원가입/로그인]
     │
     ▼
access_token (1시간) + refresh_token (30일)
     │
     │  ── 모든 🔒 API 요청에 포함 ──→  Authorization: Bearer <access_token>
     │
     ▼ (만료 시)
POST /auth/refresh { refresh_token }
     │
     ▼
새 access_token + refresh_token
```

---

## 12. 페이지네이션

모든 목록 API는 동일한 페이지네이션 형식을 따릅니다.

**요청**: `?page=1&limit=20`
**응답**:
```json
{
  "data": [...],
  "meta": {
    "total": 42,
    "page": 1,
    "limit": 20,
    "total_pages": 3
  }
}
```
