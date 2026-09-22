# AGENTS.md

このリポジトリで作業するときの判断基準。

## 公開する振る舞い

- [README の Integration model](README.md#integration-model) を利用者向けの動作契約として維持する。
  この契約を変更する場合は、README と対応する境界テストを同じ変更で更新する。
- public API を不用意に拡張する前に、既存 API で要求を満たせないことを示す。

## 内部設計

- shared abstraction は先回りして作らない。複数 module に似たコードがあっても、実際に同じ理由で
  同時に変更される実績が出るまで重複のままにする。必要になった場合も最初は `kago._internal.*`
  のような private namespace に置く。
- module が所有する runtime identifier は、augroup・extmark namespace なら `kago`、
  operatorfunc 用 global なら `_kago` で始める。

## 検証

- behavior change には regression test を追加する。
- 静的解析の警告は suppression で隠さず、型に関する警告は annotation で解決する。
- 終了前に `make check` を通す。テスト環境と実行方法は [Contributing](CONTRIBUTING.md) を参照する。
