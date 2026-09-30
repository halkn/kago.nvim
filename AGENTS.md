# AGENTS.md

このリポジトリで作業するときの判断基準。

## 公開する振る舞い

- [README の Integration model](README.md#integration-model) を利用者向けの動作契約として維持する。
  この契約を変更する場合は、README と対応する境界テストを同じ変更で更新する。
- public API を不用意に拡張する前に、既存 API で要求を満たせないことを示す。

## 内部設計

- shared abstraction は先回りして作らない。複数 module に似たコードがあっても、実際に同じ理由で
  同時に変更される実績が出るまで重複のままにする。必要になった場合も最初は `kago._internal.*`
  のような private namespace に置く。単一 module 内で使う処理は `kago.<module>._internal.*`
  に置き、依存をその module 内に閉じる。
- private であることは `local` または `_internal` namespace で示す。local 変数・関数に
  private を表すためだけの `_` 接頭辞は付けない。
- 新規の runtime identifier は highlight なら `Kago<Module><Role>`、filetype なら
  `kago-<module>-<role>`、augroup・extmark namespace なら `kago_<module>_<role>`、
  operatorfunc 用 global なら `_kago_<module>_<action>` とする。role が不要なら省略する。
  既存名はユーザー設定との接点として扱い、規則に揃えるためだけに改名しない。

## 検証

- behavior change には regression test を追加する。
- 静的解析の警告は suppression で隠さず、型に関する警告は annotation で解決する。
- 終了前に `make check` を通す。テスト環境と実行方法は [Contributing](CONTRIBUTING.md) を参照する。
