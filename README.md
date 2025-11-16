#  Apple Inc.財務分析パイプライン

モダンデータスタックツールを使用してApple社のSEC財務報告書を分析するエンドツーエンドのデータパイプライン。

[![dbt](https://img.shields.io/badge/dbt-FF694B?style=flat&logo=dbt&logoColor=white)](https://www.getdbt.com/)
[![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?style=flat&logo=google-cloud&logoColor=white)](https://cloud.google.com/bigquery)
[![Looker](https://img.shields.io/badge/Looker-4285F4?style=flat&logo=looker&logoColor=white)](https://lookerstudio.google.com/)

---

##  概要

このプロジェクトは、Apple社のSEC（米国証券取引委員会）提出書類（10-Q・10-K報告書）から財務データを抽出・変換・可視化する本番環境対応のデータパイプラインです。3層アーキテクチャによるモダンなデータエンジニアリングのベストプラクティスを実装しています。

**データ対象期間:** 2013-2015年および2018-2020年の16四半期

---

##  使用技術

| コンポーネント         | 技術 |
|---------------        |------|
| **データウェアハウス** | Google BigQuery |
| **データ変換**        | dbt Cloud |
| **可視化**            | Looker Studio |
| **バージョン管理**     | Git/GitHub |
| **テスト**            | dbt tests |
| **データソース**       | SEC EDGAR提出書類 |

---

##  アーキテクチャ
```
SEC提出書類（BigQuery公開データセット）
    ↓
 ステージング層：データクリーニング・標準化
    ↓
 マート層：ビジネスロジック・ピボット処理
    ↓
 分析層：KPI計算
    ↓
 Looker Studio：インタラクティブダッシュボード
```

### データフロー概要

| レイヤー | 入力 | 出力 | 目的 |
|---------|------|------|------|
| **生データ** | 254行（縦持ち形式） | - | SEC提出データ |
| **ステージング** | 254行 | 160行 | クリーニング、重複除去 |
| **マート** | 160行 | 16行 | ピボット済み指標 |
| **分析** | 16行 | 16行 + KPI | 比率計算済み |

---

##  プロジェクト構造
```
financials_dbt/
├── models/
│   ├── staging/
│   │   ├── stg_apple_financials.sql      # データクリーニング・重複除去
│   │   └── sources.yml                    # ソース定義
│   ├── marts/
│   │   └── facts/
│   │       ├── fct_apple_financials.sql   # ピボット済み財務指標
│   │       └── schema.yml                 # テスト・ドキュメント
│   └── intermediate/
│       ├── int_financial_ratios.sql       # KPI計算
│       └── schema.yml                     # テスト・ドキュメント
├── dbt_project.yml                        # プロジェクト設定
├── packages.yml                           # dbt依存関係
└── README.md
```

---

##  データ変換パイプライン

### 1. ステージング層: `stg_apple_financials`

**目的:** SEC生データのクリーニングと標準化

**変換処理:**
-  日付フォーマット変換: `20200930`（整数） → `2020-09-30`（DATE型）
-  NULL値と無効レコードの除去
-  10-Q（四半期）と10-K（年次）報告書のみに絞り込み
-  重複期間の除去（10-Qを10-Kより優先）
-  会計年度と四半期情報の抽出

**重要なロジック:**
```sql
-- 重複除去：期間・指標ごとに1行
ROW_NUMBER() OVER (
    PARTITION BY period_end_date, measure_tag
    ORDER BY 
        CASE WHEN form = '10-Q' THEN 1 ELSE 2 END,
        date_accepted DESC
)
```

**出力:** クリーンでユニークな期間-指標の組み合わせ160行

---

### 2. マート層: `fct_apple_financials`

**目的:** 縦持ち形式から横持ち形式への変換（ビジネス利用可能）

**変換処理:**
-  指標タグを列にピボット
-  会計期間ごとに1行
-  主要指標: 売上高、売上総利益、純利益、EPS、配当

**変換前（縦持ち形式）:**
```
period_end_date | measure_tag         | value
2020-09-30      | NetIncomeLoss      | 12,673,000,000
2020-09-30      | Revenue...         | 64,698,000,000
2020-09-30      | GrossProfit        | 24,689,000,000
```

**変換後（横持ち形式）:**
```
period_end_date | revenue        | gross_profit   | net_income
2020-09-30      | 64,698,000,000 | 24,689,000,000 | 12,673,000,000
```

**出力:** 16行（会計期間ごとに1行）

---

###  分析層: `int_financial_ratios`

**目的:** ビジネスKPIと成長指標の計算

**計算指標:**
-  **収益性指標:** 売上総利益率、純利益率
-  **成長率:** 連続期間比成長率
-  **前年同期比:** 4期間前との比較
-  **トレンド分析:** 4四半期移動平均

**主要な計算式:**
```sql
-- 売上総利益率
gross_margin_pct = (gross_profit / revenue) × 100

-- 連続期間成長率
revenue_growth_pct = ((当期売上 - 前期売上) / 前期売上) × 100

-- 前年同期比成長率
revenue_yoy_growth_pct = ((当期売上 - 4期前売上) / 4期前売上) × 100
```

**出力:** 期間ごとに20以上の計算指標を含む16行

---

##  主要指標とKPI

### 財務指標
- **売上高:** 期間ごとの総売上
- **売上総利益:** 売上高から売上原価を差し引いた利益
- **純利益:** すべての費用を差し引いた後の利益
- **EPS（希薄化後）:** 1株当たり利益
- **配当:** 宣言された1株当たり配当

### 計算比率
- **売上総利益率:** 製品レベルでの収益性
- **純利益率:** 全体的な収益性
- **売上成長率:** 連続期間の成長
- **前年同期比成長率:** 前年との比較
- **4Q移動平均:** 平滑化された四半期トレンド

---

##  ダッシュボードのハイライト

### エグゼクティブビュー
-  **スコアカード:** 最新四半期の売上高、純利益、EPS
-  **売上トレンド:** 四半期売上の折れ線グラフ（2019-2020年）
-  **利益率分析:** 売上総利益率と純利益率の推移

### 成長分析
-  **連続成長:** 前期比売上成長率
-  **YoY比較:** 前年同期比成長率
-  **パフォーマンステーブル:** 全期間の詳細指標

**[ダッシュボードを見る →](https://lookerstudio.google.com/reporting/067044c7-111f-4560-97ff-6bb1bedee721)**
---

##  セットアップ方法

### 前提条件
- BigQueryが有効化されたGoogle Cloud Platformアカウント
- dbt Cloudアカウント（またはdbt Core 1.0以上）
- BigQuery内のSEC財務データへのアクセス権

### インストール

1. **リポジトリのクローン**
```bash
git clone https://github.com/wendyyng/financials_dbt.git
cd financials_dbt
```

2. **dbtパッケージのインストール**
```bash
dbt deps
```

3. **BigQuery接続の設定**
   - dbt Cloudまたは`profiles.yml`で接続を設定
   - ソースデータセットへのアクセス権を確認

4. **パイプラインの実行**
```bash
# 全モデルの実行
dbt run

# テストの実行
dbt test

# ドキュメント生成
dbt docs generate
```

---

##  データ品質とテスト

### 実装済みテスト
-  **Not Null:** 重要フィールドに必ず値があることを確認
-  **ユニーク組み合わせ:** 期間レコードの重複がないことを検証
-  **参照整合性:** 適切なデータ系統を確認

### テスト結果
```bash
$ dbt test
Done. PASS=5 WARN=0 ERROR=0 SKIP=0 TOTAL=5
```

**全テスト合格 **

---

##  サンプルクエリ

### クエリ1: 最新四半期のパフォーマンス
```sql
SELECT 
  period_end_date,
  ROUND(revenue / 1000000000, 2) as revenue_billions,
  ROUND(net_income / 1000000000, 2) as net_income_billions,
  gross_margin_pct,
  net_margin_pct
FROM `finance-pipeline-demo.dbt_wng.int_financial_ratios`
ORDER BY period_end_date DESC
LIMIT 1;
```

### クエリ2: 前年同期比成長率
```sql
SELECT 
  period_end_date,
  ROUND(revenue / 1000000000, 2) as revenue_billions,
  revenue_growth_pct as sequential_growth,
  revenue_yoy_growth_pct as yoy_growth
FROM `finance-pipeline-demo.dbt_wng.int_financial_ratios`
WHERE revenue_yoy_growth_pct IS NOT NULL
ORDER BY period_end_date DESC;
```

---

##  実証されたスキル

### 技術スキル
- **SQL:** 複雑な変換、ウィンドウ関数、CTE、ピボット処理
- **データモデリング:** ディメンショナルモデリング、ファクト/ディメンションテーブル
- **BigQuery:** データウェアハウジング、クエリ最適化、パーティショニング
- **dbt:** メダリオンアーキテクチャ、テストフレームワーク、ドキュメント、Jinjaテンプレート
- **データ品質:** 重複除去戦略、検証、データ整合性テスト

### ビジネススキル
- **財務分析:** 財務諸表とSEC提出書類の理解
- **KPI開発:** 意味のあるビジネス指標の作成
- **データストーリーテリング:** データを実行可能なインサイトに変換

### エンジニアリング実践
- **バージョン管理:** Gitワークフロー、意味のあるコミット、ドキュメント
- **テスト:** 包括的なデータ品質チェック
- **ドキュメント:** 自己文書化コード、README、インラインコメント

---

##  主な学びと課題

### 解決した課題
1. **重複する期間:** SEC提出書類には比較用の過去データが含まれるため、スマートな重複除去が必要
2. **複数の提出タイプ:** 10-Qと10-K報告書はデータ構造が異なる
3. **データフォーマットの不一致:** 様々な日付フォーマットとNULL値への対応
4. **指標計算:** 成長率のための適切なウィンドウ関数の実装

### 実装したベストプラクティス
-  3層アーキテクチャ（ステージング → マート → 分析）
-  各層での包括的なテスト
-  明確なドキュメントとコードコメント
-  べき等な変換処理
-  ダッシュボードパフォーマンス向上のための事前計算指標

---

##  成果と影響

-  **16四半期**のクリーンで分析可能な財務データ
-  **100%のテスト合格率**（5つのデータ品質テスト）
-  重複除去ロジック後の**重複レコードゼロ**
-  dbtによる**自動化されたデータ系統**ドキュメント

---

##  関連リンク

- **ダッシュボード:** [Looker Studioダッシュボードを見る](https://lookerstudio.google.com/reporting/067044c7-111f-4560-97ff-6bb1bedee721)
- **dbtドキュメント:** [ドキュメントを見る](https://wendyyng.github.io/financials_dbt/#!/overview)
- **ソースデータ:** [SEC EDGARデータベース](https://www.sec.gov/edgar)

---
