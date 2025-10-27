module Core.DomainToDoc

import Core.DocumentModel
import Domains.ScaleDeep
import Data.List

------------------------------------------------------------
-- 도메인 모델을 문서 모델로 변환하는 명세
-- 목적: ServiceContract 같은 도메인 타입을 Document로 변환
------------------------------------------------------------

------------------------------------------------------------
-- 1. 변환 인터페이스 정의
------------------------------------------------------------

-- 문서로 변환 가능한 타입
public export
interface Documentable a where
  toDocument : a -> Document


------------------------------------------------------------
-- 2. Party → DocElement 변환
------------------------------------------------------------

public export
partyToElements : String -> Party -> List DocElement
partyToElements role party =
  [ Heading 3 ("[" ++ role ++ "]")
  , Para ("회 사 명: " ++ party.companyName)
  , Para ("대 표 자: " ++ party.representative)
  , Para ("사업자번호: " ++ party.businessNumber)
  , Para ("주    소: " ++ party.address)
  , Para ("전화번호: " ++ party.contact)
  , VSpace 10
  , Para ("(인)")
  , VSpace 5
  ]


------------------------------------------------------------
-- 3. Deliverable → DocElement 변환
------------------------------------------------------------

public export
deliverableToElement : Deliverable -> DocElement
deliverableToElement d =
  Para ("• " ++ d.name ++ " (" ++ d.dueDate ++ ")\n" ++
        "  형식: " ++ concat (intersperse ", " d.format))

public export
deliverablesToElements : List Deliverable -> List DocElement
deliverablesToElements = map deliverableToElement


------------------------------------------------------------
-- 4. ContractTerms → DocElement 변환 (각 조항)
------------------------------------------------------------

public export
article : Nat -> String -> String -> DocElement
article num title content =
  Section ("제" ++ show num ++ "조 (" ++ title ++ ")")
    [Para content, VSpace 3]

public export
articleWithList : Nat -> String -> List String -> DocElement
articleWithList num title items =
  Section ("제" ++ show num ++ "조 (" ++ title ++ ")")
    (map Para items ++ [VSpace 3])

public export
termsToArticles : ContractTerms -> List DocElement
termsToArticles terms =
  [ article 1 "계약의 목적" terms.purpose
  , article 2 "용역의 범위" terms.scope
  , article 3 "용역 기간"
      ("시작일: " ++ fst terms.duration ++ "\n" ++
       "종료일: " ++ snd terms.duration)
  , article 4 "용역 장소" terms.location
  , Section "제5조 (산출물 및 납품 일정)"
      (deliverablesToElements terms.deliverables ++ [VSpace 3])
  , article 6 "계약금액"
      ("총 계약금액: " ++ show terms.contractAmount ++ "원")
  , articleWithList 7 "대금지급 조건" terms.paymentTerms
  , article 8 "지적재산권 귀속" terms.rightsOwnership
  , article 9 "비밀유지" terms.confidentiality
  , article 10 "하자담보책임" terms.warranties
  , article 11 "불가항력" terms.forcemajeure
  , article 12 "계약해지" terms.termination
  , article 13 "분쟁해결" terms.disputeResolution
  , articleWithList 14 "기타 특약사항" terms.specialProvisions
  ]


------------------------------------------------------------
-- 5. ServiceContract → Document 변환 (전체 계약서)
------------------------------------------------------------

public export
Documentable ServiceContract where
  toDocument sc =
    let
      -- 헤더
      header =
        [ Heading 1 "용 역 계 약 서"
        , VSpace 5
        , Para ("계약번호: " ++ sc.contractNumber)
        , Para ("계약일자: " ++ sc.contractDate)
        , VSpace 5
        ]

      -- 전문
      preamble =
        [ Para (sc.client.companyName ++ "(이하 \"갑\"이라 한다)와 " ++
                sc.contractor.companyName ++ "(이하 \"을\"이라 한다)는 " ++
                "수학문항 입력 및 검수 용역에 관하여 다음과 같이 계약을 체결한다.")
        , VSpace 10
        ]

      -- 조항들
      articles = termsToArticles sc.terms

      -- 결어
      closing =
        [ VSpace 10
        , Para "본 계약의 성립을 증명하기 위하여 계약서 2부를 작성하여 갑, 을이 기명날인한 후 각 1부씩 보관한다."
        , VSpace 10
        , Para sc.contractDate
        , VSpace 10
        ]

      -- 당사자 정보
      parties = partyToElements "갑" sc.client ++ partyToElements "을" sc.contractor

      -- 첨부서류
      attachments = if length sc.attachments > 0
        then [ PageBreak
             , Heading 2 "첨부서류"
             , OrderedList sc.attachments
             ]
        else []

      -- 전체 본문
      fullBody = header ++ preamble ++ articles ++ closing ++ parties ++ attachments

      -- 메타데이터
      metadata = MkMetadata
        "용역계약서"
        (sc.client.companyName ++ " / " ++ sc.contractor.companyName)
        sc.contractDate
        sc.contractNumber

    in MkDoc metadata fullBody


------------------------------------------------------------
-- 6. 기타 도메인 타입들의 문서 변환
------------------------------------------------------------

-- TaskSpec을 간단한 문서로 변환
public export
Documentable TaskSpec where
  toDocument task =
    let
      body =
        [ Heading 1 "과업 명세서"
        , Heading 2 task.taskName
        , Para task.description
        , VSpace 5
        , Heading 3 "수행 기간"
        , Para (fst task.duration ++ " ~ " ++ snd task.duration)
        , VSpace 5
        , Heading 3 "산출물"
        ] ++ deliverablesToElements task.deliverables ++
        [ VSpace 5
        , Heading 3 "품질 기준"
        , Para task.qualityStandard
        ]

      meta = MkMetadata
        "과업명세서"
        ""
        (fst task.duration)
        ""

    in MkDoc meta body


-- Transaction을 거래명세서로 변환
public export
Documentable Transaction where
  toDocument tx =
    let
      body =
        [ Heading 1 "거래명세서"
        , VSpace 5
        , Para ("공급자: " ++ tx.supplier)
        , Para ("수령자: " ++ tx.receiver)
        , VSpace 3
        , Para ("품목: " ++ tx.item)
        , Para ("단가: " ++ show tx.unitPrice ++ "원")
        , Para ("수량: " ++ show tx.quantity)
        , HRule
        , Para ("공급가액: " ++ show tx.supplyPrice ++ "원")
        , Para ("부가세: " ++ show tx.vat ++ "원")
        , Para ("합계: " ++ show tx.totalAmount ++ "원")
        ]

      meta = MkMetadata
        "거래명세서"
        tx.supplier
        ""
        ""

    in MkDoc meta body


------------------------------------------------------------
-- 7. 헬퍼 함수들
------------------------------------------------------------

-- 문서 미리보기 (처음 n개 요소)
public export
previewDocument : Nat -> Document -> List DocElement
previewDocument n doc = take n doc.body

-- 문서 통계
public export
record DocStats where
  constructor MkDocStats
  elementCount : Nat
  sectionCount : Nat
  pageBreaks : Nat

public export
countElements : List DocElement -> Nat
countElements = length

public export
countSections : List DocElement -> Nat
countSections elems = length (filter isSection elems)
  where
    isSection : DocElement -> Bool
    isSection (Section _ _) = True
    isSection _ = False

public export
docStats : Document -> DocStats
docStats doc = MkDocStats
  (countElements doc.body)
  (countSections doc.body)
  0  -- TODO: count PageBreaks
