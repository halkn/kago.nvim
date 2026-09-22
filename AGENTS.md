# AGENTS.md

このリポジトリで作業するときの判断基準。

## 応答

- 日本語で応答する。

## 設計

- module independence を維持する。ある `kago.*` module を使うために、無関係な別 module の
  require / setup を要求しない。
- public API を不用意に拡張する前に、既存 API で要求を満たせないことを示す。
- shared abstraction は先回りして作らない。複数 module に似たコードがあっても、実際に同じ理由で
  同時に変更される実績が出るまで重複のままにする。必要になった場合も最初は `kago._internal.*`
  のような private namespace に置く。
- plugin を読み込んだだけで personal environment を変更しない。global mapping・`vim.ui.*` /
  `vim.notify` の置換・user command 登録は利用側の責務とする。module 自身の UI に必要な
  buffer-local mapping・autocmd・namespace は module が所有してよい。
- module が所有する runtime identifier（augroup・extmark namespace・operatorfunc 用 global）は
  `kago` prefix を付ける。

## 変更の進め方

- behavior change には regression test を追加する。
- 現在の plan / issue に無い大規模リファクタを、他の変更と同時に行わない。
- 終了前に `make check`（整形チェック・静的解析・module テスト）を通す。
- 静的解析の警告は suppression で隠さず、型 annotation で解決する。
