#!/usr/bin/env bash
# visions-match-lp を visions.goodwillhunting.co.jp に切り替える
#
# ⚠️ 実行前に必ずDNSを設定しておくこと（お名前.com）:
#     ホスト名: visions / TYPE: CNAME / VALUE: shinmi725810-sketch.github.io.
#
# DNS未設定のまま実行するとLPが両方のURLで見られなくなるため、
# 実際に名前解決できることを検証してからでないと進みません。
#
# 使い方:  ./switch-domain.sh --confirm

set -euo pipefail
cd "$(dirname "$0")"

NEW_HOST="visions.goodwillhunting.co.jp"
OLD_URL="https://shinmi725810-sketch.github.io/visions-match-lp/"
NEW_URL="https://${NEW_HOST}/"

if [ "${1:-}" != "--confirm" ]; then
  echo "このスクリプトは本番ドメインを切り替えます。"
  echo "DNS設定が済んでいることを確認のうえ、--confirm を付けて実行してください:"
  echo "    ./switch-domain.sh --confirm"
  exit 1
fi

echo "▶ 1/5 DNSの検証（実際に名前解決を試行）"
if ! python3 -c "import socket,sys; socket.getaddrinfo('${NEW_HOST}', 443)" 2>/dev/null; then
  echo "❌ 中断: ${NEW_HOST} を名前解決できません。"
  echo "   考えられる原因:"
  echo "     - お名前.comでCNAMEレコードがまだ未設定"
  echo "     - DNSの反映待ち（最大数時間）"
  echo "     - この端末からDNSに到達できない"
  echo "   いずれの場合も、切り替えるとLPが落ちるため実行しません。"
  exit 1
fi
echo "  ✅ ${NEW_HOST} は名前解決できました"

echo "▶ 2/5 切替先がGitHub Pagesを向いているか確認"
if ! curl -sI -m 20 "http://${NEW_HOST}/" | head -1 | grep -qE 'HTTP/[0-9.]+ [0-9]{3}'; then
  echo "  ⚠️ ${NEW_HOST} からHTTP応答がありません（DNS反映直後は正常なことがあります）"
  echo "     このまま進めますが、切替後すぐに反映されない可能性があります。"
fi

echo "▶ 3/5 CNAMEファイルを作成"
printf '%s\n' "$NEW_HOST" > CNAME
echo "  ✅ CNAME → $NEW_HOST"

echo "▶ 4/5 canonical / og:url / twitter を新ドメインへ書き換え"
python3 - "$OLD_URL" "$NEW_URL" <<'PY'
import sys, pathlib
old, new = sys.argv[1], sys.argv[2]
total = 0
for f in ("index.html", "lp-shimei.html"):
    p = pathlib.Path(f)
    s = p.read_text(encoding="utf-8")
    n = s.count(old)
    if n:
        p.write_text(s.replace(old, new), encoding="utf-8")
    print(f"  {f}: {n}箇所を置換")
    total += n
print(f"  合計 {total}箇所")
PY

if ls googlead*.html >/dev/null 2>&1; then
  echo "  ℹ️ $(ls googlead*.html) は同一リポジトリのため新ドメインでも配信されます"
  echo "     ただしGoogle広告側で「所有権の再確認」が別途必要です"
fi

echo "▶ 5/5 コミット＆プッシュ"
git add -A
git commit -m "chore: 独自ドメイン ${NEW_HOST} へ移行

- CNAMEファイルを追加
- canonical / og:url / twitter:url を新ドメインへ更新"
git push origin gh-pages

echo
echo "✅ 完了。次にGitHub側で確認:"
echo "   Settings → Pages → Custom domain = ${NEW_HOST}"
echo "   「Enforce HTTPS」は証明書発行後（最大24h）にON"
echo
echo "▼ 切り戻しが必要になったら:"
echo "   git revert --no-edit HEAD && git push origin gh-pages"
