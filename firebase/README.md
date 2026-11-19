# Firebase (가족 공유)

iOS(SwiftUI)와 Android(Flutter) 앱이 **같이 쓰는** Firebase 프로젝트 설정입니다.

- 프로젝트: `babylog-leeyuno` (Spark 무료 플랜)
- Firestore: `(default)`, 서울 리전 `asia-northeast3`
- 인증: 익명 로그인 (콘솔 > Authentication > 로그인 방법 > 익명)

## 구조

```
families/{familyId}                 { members: [uid], createdBy, createdAt, joinCode? }
families/{familyId}/babies/{id}      아기 프로필 (사진 제외)
families/{familyId}/events/{id}      기록
families/{familyId}/weights/{id}     몸무게
invites/{code}                       { familyId, createdBy, expiresAt }  6자리, 24시간
```

- 문서 형식은 **백업 JSON과 같습니다**(iOS `BackupService`, Android `Backup`). 그래서 두 앱이 같은 문서를 읽고 씁니다.
- **ID는 항상 소문자 UUID**입니다. iOS의 `uuidString`은 대문자라서, 그대로 쓰면 같은 기록이 두 문서로 생깁니다.

## 보안 규칙 (`firestore.rules`)

- 가족 구성원(`members`)만 그 가족의 데이터를 읽고 쓸 수 있습니다.
- 가족에 들어오는 방법은 하나입니다. 유효한 초대 코드로 **자기 uid 하나만** `members` 끝에 추가하는 것입니다.
- 초대 코드는 단건 조회만 됩니다(목록 조회 금지).

배포:
```sh
cd firebase && firebase deploy --only firestore --project babylog-leeyuno
```

규칙을 바꾸면 에뮬레이터로 공격 테스트를 다시 돌립니다(JDK 21 필요). 확인 항목은 외부인 접근, 코드 없는 참여, 남 추가, 만료 코드, 다른 가족 코드 등 26개입니다.

## 앱 설정 파일

| 앱 | 파일 | 저장소 |
|---|---|---|
| iOS | `BabyLog/GoogleService-Info.plist` | **커밋 안 함**(공개 저장소). 빌드 단계 "Copy Firebase Config (if present)"가 파일이 있을 때만 복사하고, 없으면 가족 공유만 꺼집니다 |
| Android | `android/app/google-services.json` | 비공개 저장소에 포함 |

다시 받는 법: `firebase apps:sdkconfig IOS --project babylog-leeyuno -o BabyLog/GoogleService-Info.plist`
