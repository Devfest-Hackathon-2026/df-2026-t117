# 訳の点検レポート（Gemini。Cloud Translation の逆翻訳は未実施）

`tools/i18n-check/check.mjs` が生成（手で編集しない）。生成日 2026-11-10。

Flutter アプリ（`apps/ar_guide`）の誘導の文と警報の用語を、英語の原文から Gemini で訳し直し、アプリの現在の訳と比べたもの（`mocks/evacuate/docs/architecture.md` の D1 / D12）。**報告だけで、アプリの文と音声ファイルは変えていない。**

## まとめ

- 点検した文: 88 件 × 4 言語 = 352 件（原文は英語）
- 訳し直し・判定のモデル: `gemini-3.5-flash`（Vertex AI、global）
- 逆翻訳: **未実施**（Cloud Translation API が使えなかった: HTTP 403: プロジェクトで translate.googleapis.com が有効になっていない）。判定は Gemini が訳文を直接読んで行った
- 判定: Gemini（構造化出力）。Gemini 自身の訳と比べるので、最終判断は人が行う
- **注意: 警報の公式の用語（気象庁の多言語辞書）についての指摘や案は Gemini の知識によるもので、辞書そのものとは照合していない。** 用語を直す前に、気象庁の多言語辞書で確かめる

| 言語 | 要修正（major） | 改善の余地（minor） | 問題なし |
|---|---|---|---|
| ja | 0 | 7 | 81 |
| zh-Hans | 0 | 2 | 86 |
| ko | 0 | 8 | 80 |
| ar | 0 | 6 | 82 |

### 特に重要な指摘（major）

なし。

## 要確認の一覧（major / minor）

| キー | 言語 | 原文 | 現在の訳 | Gemini の訳 | 逆翻訳（現在） | 逆翻訳（Gemini） | 判定 | 理由 |
|---|---|---|---|---|---|---|---|---|
| s01.car | ar | Pull over. Stay inside. | توقف وابقَ في السيارة | انحز جانباً وتوقف. ابقَ في الداخل. |  |  | minor | currentは「Pull over（路肩に寄せる）」のニュアンスが抜けている。 |
| s02.carSub | ja | Wait until the shaking stops | 揺れがおさまるまで | 揺れが収まるまで待つ |  |  | minor | 「待つ」などの動詞がないため、geminiの方が明確。 |
| s02.carSub | ko | Wait until the shaking stops | 흔들림이 멈출 때까지 | 흔들림이 멈출 때까지 기다리십시오 |  |  | minor | 「待つ」に相当する動詞が抜けているため、geminiの方が良い。 |
| s02.carSub | ar | Wait until the shaking stops | حتى يتوقف الاهتزاز | انتظر حتى يتوقف الاهتزاز |  |  | minor | 「待て」という動詞が抜けており、geminiの方が正確。 |
| guideDict.followSigns | ja | Follow the blue evacuation signs | 青い津波避難の標識に従う | 青い避難標識に従ってください |  |  | minor | 「従う」より「従ってください」や「進んでください」が自然。 |
| bandDict.downgrade | ko | DOWNGRADED | 격하 | 하향 조정 |  |  | minor | 「격하」より「하향 조정（下向調整）」の方が自然です。 |
| cardDict.approx | ja | Location approximate | 現在地はおおまか | おおよその位置 |  |  | minor | 「現在地はおおまか」より「おおよその位置」の方が自然で簡潔です。 |
| cardDict.highest | ja | (highest announced) | （これまでの最大） | (発表された最大値) |  |  | minor | 「これまでの最大」より「発表された最大値」の方が正確。 |
| cardDict.highest | ko | (highest announced) | (지금까지 최고) | (발표된 최대치) |  |  | minor | currentは「これまで」だが、geminiの「発表された最大値」が正確。 |
| push.tsunami-advisory | ar | Tsunami Advisory | إشعار تسونامي | تنبيه من تسونامي |  |  | minor | 気象庁の公式対訳では「تنبيه من تسونامي」が使われています。 |
| push.cancelled | ja | Tsunami alert cancelled | 津波の情報は取り消されました | 津波警報・注意報は解除されました |  |  | minor | 「津波警報・注意報は解除されました」の方が気象庁の表現に近く適切。 |
| push.cancelled | zh-Hans | Tsunami alert cancelled | 海啸信息已取消 | 海啸警报已解除 |  |  | minor | 「海啸警报已解除」の方が気象庁の公式訳（警报解除）に近く適切。 |
| push.cancelled | ko | Tsunami alert cancelled | 쓰나미 정보가 취소되었습니다 | 쓰나미 경보·주의보가 해제되었습니다 |  |  | minor | 「쓰나미 경보·주의보가 해제되었습니다」が気象庁の表現に近く適切。 |
| commonStrings.simulatedAlert | ja | SIMULATED ALERT | 模擬アラート | 訓練警報 |  |  | minor | 「訓練警報」の方が防災アプリの表現として自然で分かりやすい。 |
| commonStrings.onHighGround | ja | On high ground | 高台に着いた | 高台に避難中 |  |  | minor | 「高台に着いた」より「高台に避難中」や「高台にいる」が適切。 |
| commonStrings.onHighGround | zh-Hans | On high ground | 已到高处 | 已在高处 |  |  | minor | 「已到高处」は到着した動作を指すが、状態としてはgeminiが自然。 |
| commonStrings.onHighGround | ko | On high ground | 고지대 도착 | 고지대에 있음 |  |  | minor | 「고지대 도착（到着）」より「고지대에 있음（いる）」が状態を示す。 |
| commonStrings.onHighGround | ar | On high ground | وصلت إلى مكان مرتفع | على أرض مرتفعة |  |  | minor | currentは「到着した」という動詞表現。状態を示すgeminiが良い。 |
| commonStrings.badgeTsunamiAdvisory | ko | TSUNAMI ADVISORY | 쓰나미 주의보 | 지진해일주의보 |  |  | minor | 気象庁の公式訳は「지진해일주의보」です。 |
| commonStrings.badgeTsunamiAdvisory | ar | TSUNAMI ADVISORY | إشعار تسونامي | تنبيه من تسونامي |  |  | minor | 気象庁の公式訳は「تنبيه من تسونامي」です。 |
| commonStrings.badgeTsunamiWarning | ko | TSUNAMI WARNING | 쓰나미 경보 | 지진해일 경보 |  |  | minor | 気象庁の公式訳語は「지진해일 경보」です。 |
| commonStrings.badgeMajorTsunamiWarning | ko | MAJOR TSUNAMI WARNING | 대형 쓰나미 경보 | 대쓰나미경보 |  |  | minor | 気象庁の公式対訳は「대쓰나미경보（大津波警報）」です。 |
| commonStrings.levelAdvisory | ar | Advisory | إشعار | تحذير |  |  | minor | 気象庁対訳は「إرشاد」ですが、geminiの「تحذير」は警報（Warning）を意味するため現行がより適切です。 |

## 全件

| キー | 言語 | 原文 | 現在の訳 | Gemini の訳 | 逆翻訳（現在） | 逆翻訳（Gemini） | 判定 |
|---|---|---|---|---|---|---|---|
| s01.protect | ja | Protect your head | 頭を守れ | 頭を守って |  |  | ok |
| s01.protect | zh-Hans | Protect your head | 保护头部 | 保护头部 |  |  | ok |
| s01.protect | ko | Protect your head | 머리를 보호하세요 | 머리를 보호하세요 |  |  | ok |
| s01.protect | ar | Protect your head | احمِ رأسك | احمِ رأسك |  |  | ok |
| s01.car | ja | Pull over. Stay inside. | 停車。車内で待つ。 | 車を左に寄せて停車。車内で待機。 |  |  | ok |
| s01.car | zh-Hans | Pull over. Stay inside. | 靠边停车，留在车内 | 靠边停车。留在车内。 |  |  | ok |
| s01.car | ko | Pull over. Stay inside. | 정차하고 차 안에 머무르세요 | 차를 세우십시오. 차 안에 머무르십시오. |  |  | ok |
| s01.car | ar | Pull over. Stay inside. | توقف وابقَ في السيارة | انحز جانباً وتوقف. ابقَ في الداخل. |  |  | minor |
| s01.outdoors | ja | Protect your head | 頭を守れ | 頭を守って |  |  | ok |
| s01.outdoors | zh-Hans | Protect your head | 保护头部 | 保护头部 |  |  | ok |
| s01.outdoors | ko | Protect your head | 머리를 보호하세요 | 머리를 보호하세요 |  |  | ok |
| s01.outdoors | ar | Protect your head | احمِ رأسك | احمِ رأسك |  |  | ok |
| s01.goNow | ja | Go uphill NOW | 今すぐ高台へ | 今すぐ高台へ！ |  |  | ok |
| s01.goNow | zh-Hans | Go uphill NOW | 立即去高处 | 立刻往高处避难！ |  |  | ok |
| s01.goNow | ko | Go uphill NOW | 지금 바로 높은 곳으로 | 지금 즉시 고지대로 대피하십시오! |  |  | ok |
| s01.goNow | ar | Go uphill NOW | اصعد إلى مكان مرتفع الآن | اتجه إلى المرتفعات فورًا! |  |  | ok |
| s01.go | ja | Go uphill | 高台へ | 高台へ |  |  | ok |
| s01.go | zh-Hans | Go uphill | 去高处 | 往高处走 |  |  | ok |
| s01.go | ko | Go uphill | 높은 곳으로 | 높은 곳으로 가십시오 |  |  | ok |
| s01.go | ar | Go uphill | اصعد إلى مكان مرتفع | اتجه إلى مكان مرتفع |  |  | ok |
| s01.stay | ja | Stay here | ここで待機 | その場に留まって |  |  | ok |
| s01.stay | zh-Hans | Stay here | 留在这里 | 留在原地 |  |  | ok |
| s01.stay | ko | Stay here | 여기에 머무르세요 | 그 자리에 머무르십시오 |  |  | ok |
| s01.stay | ar | Stay here | ابقَ هنا | ابقَ في مكانك |  |  | ok |
| s01.check | ja | Check updates | 情報を確認 | 最新情報を確認 |  |  | ok |
| s01.check | zh-Hans | Check updates | 查看最新信息 | 查看最新信息 |  |  | ok |
| s01.check | ko | Check updates | 정보를 확인하세요 | 업데이트 확인 |  |  | ok |
| s01.check | ar | Check updates | تحقق من التحديثات | تحقق من التحديثات |  |  | ok |
| s02.indoors | ja | Protect your head | 頭を守れ | 頭を守って |  |  | ok |
| s02.indoors | zh-Hans | Protect your head | 保护头部 | 保护头部 |  |  | ok |
| s02.indoors | ko | Protect your head | 머리를 보호하세요 | 머리를 보호하십시오 |  |  | ok |
| s02.indoors | ar | Protect your head | احمِ رأسك | احمِ رأسك |  |  | ok |
| s02.outdoors | ja | Protect your head | 頭を守れ | 頭を守って |  |  | ok |
| s02.outdoors | zh-Hans | Protect your head | 保护头部 | 保护头部 |  |  | ok |
| s02.outdoors | ko | Protect your head | 머리를 보호하세요 | 머리를 보호하십시오 |  |  | ok |
| s02.outdoors | ar | Protect your head | احمِ رأسك | احمِ رأسك |  |  | ok |
| s02.outdoorsSub | ja | Stay away from buildings | 建物から離れる | 建物から離れて |  |  | ok |
| s02.outdoorsSub | zh-Hans | Stay away from buildings | 远离建筑物 | 远离建筑物 |  |  | ok |
| s02.outdoorsSub | ko | Stay away from buildings | 건물에서 떨어지세요 | 건물에서 떨어지십시오 |  |  | ok |
| s02.outdoorsSub | ar | Stay away from buildings | ابتعد عن المباني | ابتعد عن المباني |  |  | ok |
| s02.car | ja | Pull over. Stay inside. | 停車。車内で待つ。 | 車を左に寄せて停車。車内で待機。 |  |  | ok |
| s02.car | zh-Hans | Pull over. Stay inside. | 靠边停车，留在车内。 | 靠边停车。留在车内。 |  |  | ok |
| s02.car | ko | Pull over. Stay inside. | 정차하고 차 안에 머무르세요. | 차를 길가에 대십시오. 차 안에 머무르십시오. |  |  | ok |
| s02.car | ar | Pull over. Stay inside. | توقف وابقَ في السيارة. | اركن السيارة جانباً. ابقَ في الداخل. |  |  | ok |
| s02.carSub | ja | Wait until the shaking stops | 揺れがおさまるまで | 揺れが収まるまで待つ |  |  | minor |
| s02.carSub | zh-Hans | Wait until the shaking stops | 等到摇晃停止 | 等摇晃停止 |  |  | ok |
| s02.carSub | ko | Wait until the shaking stops | 흔들림이 멈출 때까지 | 흔들림이 멈출 때까지 기다리십시오 |  |  | minor |
| s02.carSub | ar | Wait until the shaking stops | حتى يتوقف الاهتزاز | انتظر حتى يتوقف الاهتزاز |  |  | minor |
| s02.switchSituation | ja | Change situation | 状況を切り替え | 状況を変更 |  |  | ok |
| s02.switchSituation | zh-Hans | Change situation | 切换场景 | 更改状况 |  |  | ok |
| s02.switchSituation | ko | Change situation | 상황 전환 | 상황 변경 |  |  | ok |
| s02.switchSituation | ar | Change situation | تغيير الحالة | تغيير الوضع |  |  | ok |
| s03.headline | ja | Go uphill. | 高台へ。 | 高台へ |  |  | ok |
| s03.headline | zh-Hans | Go uphill. | 去高处。 | 往高处走 |  |  | ok |
| s03.headline | ko | Go uphill. | 높은 곳으로. | 높은 곳으로 가십시오 |  |  | ok |
| s03.headline | ar | Go uphill. | اصعد إلى مكان مرتفع. | اصعد إلى مكان مرتفع |  |  | ok |
| s03.now | ja | NOW | 今すぐ | 今すぐ |  |  | ok |
| s03.now | zh-Hans | NOW | 立即 | 立刻 |  |  | ok |
| s03.now | ko | NOW | 지금 바로 | 지금 당장 |  |  | ok |
| s03.now | ar | NOW | الآن | الآن |  |  | ok |
| s03.leaveCar | ja | Leave the car. Go on foot. | 車を降りて、歩いて避難。 | 車を置いて、歩いて避難してください。 |  |  | ok |
| s03.leaveCar | zh-Hans | Leave the car. Go on foot. | 下车，步行避难。 | 弃车步行。 |  |  | ok |
| s03.leaveCar | ko | Leave the car. Go on foot. | 차에서 내려 걸어서 대피하세요. | 차를 두고 걸어서 대피하십시오. |  |  | ok |
| s03.leaveCar | ar | Leave the car. Go on foot. | اترك السيارة وامشِ. | اترك السيارة. اذهب سيرًا على الأقدام. |  |  | ok |
| s05.headline | ja | Go uphill. | 高台へ。 | 高台へ |  |  | ok |
| s05.headline | zh-Hans | Go uphill. | 去高处。 | 往高处走 |  |  | ok |
| s05.headline | ko | Go uphill. | 높은 곳으로. | 높은 곳으로 가십시오. |  |  | ok |
| s05.headline | ar | Go uphill. | اصعد إلى مكان مرتفع. | اصعد إلى مكان مرتفع. |  |  | ok |
| s05.guide | ja | TSUNAMI GUIDE | 津波ガイド | 津波ガイド |  |  | ok |
| s05.guide | zh-Hans | TSUNAMI GUIDE | 海啸指南 | 海啸指南 |  |  | ok |
| s05.guide | ko | TSUNAMI GUIDE | 쓰나미 안내 | 지진해일 가이드 |  |  | ok |
| s05.guide | ar | TSUNAMI GUIDE | دليل التسونامي | دليل التسونامي |  |  | ok |
| s05.leaveCar | ja | Leave the car. Go on foot. | 車を降りて、歩いて避難。 | 車を置いて、歩いて避難してください。 |  |  | ok |
| s05.leaveCar | zh-Hans | Leave the car. Go on foot. | 下车，步行避难。 | 弃车步行。 |  |  | ok |
| s05.leaveCar | ko | Leave the car. Go on foot. | 차에서 내려 걸어서 대피하세요. | 차를 두고 걸어서 대피하십시오. |  |  | ok |
| s05.leaveCar | ar | Leave the car. Go on foot. | اترك السيارة وامشِ. | اترك السيارة. اذهب سيرًا على الأقدام. |  |  | ok |
| s06.headline | ja | Stay here. | ここで待機。 | ここで待機してください |  |  | ok |
| s06.headline | zh-Hans | Stay here. | 留在这里。 | 在此停留 |  |  | ok |
| s06.headline | ko | Stay here. | 여기에 머무르세요. | 이곳에 머무르십시오 |  |  | ok |
| s06.headline | ar | Stay here. | ابقَ هنا. | ابقَ هنا |  |  | ok |
| s06.active | ja | ACTIVE | 発表中 | 作動中 |  |  | ok |
| s06.active | zh-Hans | ACTIVE | 生效中 | 运行中 |  |  | ok |
| s06.active | ko | ACTIVE | 발령 중 | 작동 중 |  |  | ok |
| s06.active | ar | ACTIVE | ساري | نشط |  |  | ok |
| guideDict.goHigher | ja | Go higher. | もっと高い所へ。 | さらに高いところへ |  |  | ok |
| guideDict.goHigher | zh-Hans | Go higher. | 去更高处。 | 往更高处 |  |  | ok |
| guideDict.goHigher | ko | Go higher. | 더 높은 곳으로. | 더 높은 곳으로 가십시오 |  |  | ok |
| guideDict.goHigher | ar | Go higher. | اصعد إلى مكان أعلى. | اصعد إلى مكان أعلى |  |  | ok |
| guideDict.followSigns | ja | Follow the blue evacuation signs | 青い津波避難の標識に従う | 青い避難標識に従ってください |  |  | minor |
| guideDict.followSigns | zh-Hans | Follow the blue evacuation signs | 跟随蓝色海啸避难标志 | 沿蓝色避难标志前进 |  |  | ok |
| guideDict.followSigns | ko | Follow the blue evacuation signs | 파란색 쓰나미 대피 표지판을 따라가세요 | 파란색 대피 표지판을 따라가십시오 |  |  | ok |
| guideDict.followSigns | ar | Follow the blue evacuation signs | اتبع لافتات الإخلاء الزرقاء | اتبع لافتات الإخلاء الزرقاء |  |  | ok |
| guideDict.setLocation | ja | Set location | 現在地を設定 | 位置を設定 |  |  | ok |
| guideDict.setLocation | zh-Hans | Set location | 设置位置 | 设置位置 |  |  | ok |
| guideDict.setLocation | ko | Set location | 위치 설정 | 위치 설정 |  |  | ok |
| guideDict.setLocation | ar | Set location | حدد الموقع | تعيين الموقع |  |  | ok |
| bandDict.upgrade | ja | UPGRADED | 格上げ | 格上げ |  |  | ok |
| bandDict.upgrade | zh-Hans | UPGRADED | 已升级 | 升级 |  |  | ok |
| bandDict.upgrade | ko | UPGRADED | 격상 | 격상 |  |  | ok |
| bandDict.upgrade | ar | UPGRADED | رُفع المستوى | ترقية |  |  | ok |
| bandDict.raise | ja | HEIGHT RAISED | 高さ引き上げ | 予想高さ引き上げ |  |  | ok |
| bandDict.raise | zh-Hans | HEIGHT RAISED | 预计高度上调 | 预测高度上调 |  |  | ok |
| bandDict.raise | ko | HEIGHT RAISED | 예상 높이 상향 | 예상 높이 상향 |  |  | ok |
| bandDict.raise | ar | HEIGHT RAISED | رُفع الارتفاع المتوقع | زيادة الارتفاع المتوقع |  |  | ok |
| bandDict.downgrade | ja | DOWNGRADED | 格下げ | 格下げ |  |  | ok |
| bandDict.downgrade | zh-Hans | DOWNGRADED | 已降级 | 降级 |  |  | ok |
| bandDict.downgrade | ko | DOWNGRADED | 격하 | 하향 조정 |  |  | minor |
| bandDict.downgrade | ar | DOWNGRADED | خُفض المستوى | تخفيض الدرجة |  |  | ok |
| bandDict.expected | ja | Expected {h} | 予想 {h} | 予想される高さ {h} |  |  | ok |
| bandDict.expected | zh-Hans | Expected {h} | 预计 {h} | 预测高度 {h} |  |  | ok |
| bandDict.expected | ko | Expected {h} | 예상 {h} | 예상 높이 {h} |  |  | ok |
| bandDict.expected | ar | Expected {h} | المتوقع {h} | الارتفاع المتوقع {h} |  |  | ok |
| bandDict.keepGoing | ja | Keep going to high ground | このまま高台へ | 引き続き高台へ避難してください |  |  | ok |
| bandDict.keepGoing | zh-Hans | Keep going to high ground | 继续前往高处 | 继续向高处避难 |  |  | ok |
| bandDict.keepGoing | ko | Keep going to high ground | 계속 높은 곳으로 가세요 | 계속해서 높은 곳으로 대피하십시오 |  |  | ok |
| bandDict.keepGoing | ar | Keep going to high ground | واصل التوجه إلى مكان مرتفع | استمروا في التوجه إلى المرتفعات |  |  | ok |
| bandDict.stayAll | ja | Stay until all alerts are lifted | すべて解除されるまで待機 | すべての警報が解除されるまでその場にとどまってください |  |  | ok |
| bandDict.stayAll | zh-Hans | Stay until all alerts are lifted | 在全部警报解除前请留在此处 | 在所有警报解除前，请留在原地 |  |  | ok |
| bandDict.stayAll | ko | Stay until all alerts are lifted | 모든 경보가 해제될 때까지 머무르세요 | 모든 경보가 해제될 때까지 머무르십시오 |  |  | ok |
| bandDict.stayAll | ar | Stay until all alerts are lifted | ابقَ حتى تُرفع جميع التنبيهات | ابقَ في مكانك حتى إلغاء جميع التحذيرات |  |  | ok |
| cardDict.title | ja | Why here | ここで待つ理由 | なぜここなのか |  |  | ok |
| cardDict.title | zh-Hans | Why here | 为什么在这里 | 为什么是这里 |  |  | ok |
| cardDict.title | ko | Why here | 여기서 기다리는 이유 | 왜 이곳인가 |  |  | ok |
| cardDict.title | ar | Why here | لماذا هنا | لماذا هنا |  |  | ok |
| cardDict.approx | ja | Location approximate | 現在地はおおまか | おおよその位置 |  |  | minor |
| cardDict.approx | zh-Hans | Location approximate | 位置为大致位置 | 大致位置 |  |  | ok |
| cardDict.approx | ko | Location approximate | 위치가 대략적입니다 | 대략적인 위치 |  |  | ok |
| cardDict.approx | ar | Location approximate | الموقع تقريبي | الموقع تقريبي |  |  | ok |
| cardDict.elevation | ja | Elevation {v} | 標高 {v} | 標高 {v} |  |  | ok |
| cardDict.elevation | zh-Hans | Elevation {v} | 海拔 {v} | 海拔 {v} |  |  | ok |
| cardDict.elevation | ko | Elevation {v} | 해발 {v} | 해발 {v} |  |  | ok |
| cardDict.elevation | ar | Elevation {v} | الارتفاع {v} | الارتفاع {v} |  |  | ok |
| cardDict.elevUnknown | ja | Elevation unknown | 標高は不明 | 標高不明 |  |  | ok |
| cardDict.elevUnknown | zh-Hans | Elevation unknown | 海拔未知 | 海拔未知 |  |  | ok |
| cardDict.elevUnknown | ko | Elevation unknown | 해발 알 수 없음 | 해발 불명 |  |  | ok |
| cardDict.elevUnknown | ar | Elevation unknown | الارتفاع غير معروف | الارتفاع غير معروف |  |  | ok |
| cardDict.expected | ja | Expected tsunami {h} | 予想される津波 {h} | 予想される津波 {h} |  |  | ok |
| cardDict.expected | zh-Hans | Expected tsunami {h} | 预计海啸 {h} | 预测海啸 {h} |  |  | ok |
| cardDict.expected | ko | Expected tsunami {h} | 예상 쓰나미 {h} | 예상되는 쓰나미 {h} |  |  | ok |
| cardDict.expected | ar | Expected tsunami {h} | التسونامي المتوقع {h} | تسونامي المتوقع {h} |  |  | ok |
| cardDict.highest | ja | (highest announced) | （これまでの最大） | (発表された最大値) |  |  | minor |
| cardDict.highest | zh-Hans | (highest announced) | （已发布的最高值） | (已发布的最高值) |  |  | ok |
| cardDict.highest | ko | (highest announced) | (지금까지 최고) | (발표된 최대치) |  |  | minor |
| cardDict.highest | ar | (highest announced) | (الأعلى المُعلن) | (أعلى قيمة معلنة) |  |  | ok |
| cardDict.above | ja | {n} m above forecast | 予想より {n} m 高い | 予測より{n}m高い |  |  | ok |
| cardDict.above | zh-Hans | {n} m above forecast | 比预计高 {n} 米 | 比预测高{n}米 |  |  | ok |
| cardDict.above | ko | {n} m above forecast | 예상보다 {n}m 높음 | 예상보다 {n}m 높음 |  |  | ok |
| cardDict.above | ar | {n} m above forecast | أعلى من المتوقع بـ {n} م | أعلى بـ {n} م من المتوقع |  |  | ok |
| cardDict.below | ja | {n} m below forecast | 予想より {n} m 低い | 予想より{n}m低い |  |  | ok |
| cardDict.below | zh-Hans | {n} m below forecast | 比预计低 {n} 米 | 比预测低{n}米 |  |  | ok |
| cardDict.below | ko | {n} m below forecast | 예상보다 {n}m 낮음 | 예상보다 {n}m 낮음 |  |  | ok |
| cardDict.below | ar | {n} m below forecast | أدنى من المتوقع بـ {n} م | أقل من المتوقع بـ {n} م |  |  | ok |
| cardDict.stayUntil | ja | Stay until the warning is lifted | 警報が解除されるまで待機 | 警報が解除されるまで待機してください |  |  | ok |
| cardDict.stayUntil | zh-Hans | Stay until the warning is lifted | 请等到警报解除 | 警报解除前请留在原地 |  |  | ok |
| cardDict.stayUntil | ko | Stay until the warning is lifted | 경보가 해제될 때까지 머무르세요 | 경보가 해제될 때까지 머무르십시오 |  |  | ok |
| cardDict.stayUntil | ar | Stay until the warning is lifted | ابقَ حتى يُرفع التحذير | ابقَ في مكانك حتى يتم رفع التحذير |  |  | ok |
| cardDict.staff | ja | Follow staff instructions | 係員の指示に従う | 係員の指示に従ってください |  |  | ok |
| cardDict.staff | zh-Hans | Follow staff instructions | 请听从工作人员的指示 | 听从工作人员指示 |  |  | ok |
| cardDict.staff | ko | Follow staff instructions | 직원의 안내에 따르세요 | 직원의 지시에 따르십시오 |  |  | ok |
| cardDict.staff | ar | Follow staff instructions | اتبع تعليمات الموظفين | اتبع تعليمات الموظفين |  |  | ok |
| heightDict.over10 | ja | over 10 m | 10 m 超 | 10m超 |  |  | ok |
| heightDict.over10 | zh-Hans | over 10 m | 超过 10 米 | 超过10m |  |  | ok |
| heightDict.over10 | ko | over 10 m | 10m 초과 | 10m 초과 |  |  | ok |
| heightDict.over10 | ar | over 10 m | أكثر من 10 م | أكثر من 10 م |  |  | ok |
| heightDict.huge | ja | huge | 巨大 | 巨大 |  |  | ok |
| heightDict.huge | zh-Hans | huge | 巨大 | 巨大 |  |  | ok |
| heightDict.huge | ko | huge | 거대 | 거대 |  |  | ok |
| heightDict.huge | ar | huge | هائل | ضخم |  |  | ok |
| heightDict.high | ja | high | 高い | 高い |  |  | ok |
| heightDict.high | zh-Hans | high | 高 | 高 |  |  | ok |
| heightDict.high | ko | high | 높음 | 높음 |  |  | ok |
| heightDict.high | ar | high | مرتفع | مرتفع |  |  | ok |
| notifyBodyDict.upgrade | ja | Tsunami alert upgraded | 津波の警報が格上げされました | 津波警報が引き上げられました。 |  |  | ok |
| notifyBodyDict.upgrade | zh-Hans | Tsunami alert upgraded | 海啸警报已升级 | 海啸预警已升级。 |  |  | ok |
| notifyBodyDict.upgrade | ko | Tsunami alert upgraded | 쓰나미 경보가 격상되었습니다 | 쓰나미 경보가 격상되었습니다. |  |  | ok |
| notifyBodyDict.upgrade | ar | Tsunami alert upgraded | تم رفع مستوى تنبيه التسونامي | تم رفع درجة إنذار التسونامي. |  |  | ok |
| notifyBodyDict.raise | ja | Expected tsunami height raised | 予想される津波の高さが引き上げられました | 予想される津波の高さが引き上げられました |  |  | ok |
| notifyBodyDict.raise | zh-Hans | Expected tsunami height raised | 预计海啸高度已上调 | 预计海啸高度已调高 |  |  | ok |
| notifyBodyDict.raise | ko | Expected tsunami height raised | 예상 쓰나미 높이가 상향되었습니다 | 예상되는 쓰나미 높이가 상향되었습니다 |  |  | ok |
| notifyBodyDict.raise | ar | Expected tsunami height raised | تم رفع الارتفاع المتوقع للتسونامي | تم رفع الارتفاع المتوقع للتسونامي |  |  | ok |
| turnSpeechDict.right | ja | Turn right in {n} meters. | {n}メートル先、右です。 | {n}メートル先、右です。 |  |  | ok |
| turnSpeechDict.right | zh-Hans | Turn right in {n} meters. | 前方{n}米右转。 | {n}米后右转。 |  |  | ok |
| turnSpeechDict.right | ko | Turn right in {n} meters. | {n}미터 앞에서 오른쪽입니다. | {n}미터 앞에서 우회전하세요. |  |  | ok |
| turnSpeechDict.right | ar | Turn right in {n} meters. | انعطف يمينًا بعد {n} متر. | انعطف يمينًا بعد {n} متر. |  |  | ok |
| turnSpeechDict.left | ja | Turn left in {n} meters. | {n}メートル先、左です。 | {n}メートル先、左です。 |  |  | ok |
| turnSpeechDict.left | zh-Hans | Turn left in {n} meters. | 前方{n}米左转。 | {n}米后左转。 |  |  | ok |
| turnSpeechDict.left | ko | Turn left in {n} meters. | {n}미터 앞에서 왼쪽입니다. | {n}미터 앞에서 좌회전하십시오. |  |  | ok |
| turnSpeechDict.left | ar | Turn left in {n} meters. | انعطف يسارًا بعد {n} متر. | انعطف يسارًا بعد {n} متر. |  |  | ok |
| turnSpeechDict.straight | ja | Go straight for {n} meters. | このまま{n}メートル直進です。 | {n}メートル直進。 |  |  | ok |
| turnSpeechDict.straight | zh-Hans | Go straight for {n} meters. | 直行{n}米。 | 直行{n}米。 |  |  | ok |
| turnSpeechDict.straight | ko | Go straight for {n} meters. | {n}미터 직진하세요. | {n}미터 직진하세요. |  |  | ok |
| turnSpeechDict.straight | ar | Go straight for {n} meters. | تابع إلى الأمام لمسافة {n} متر. | سر مستقيمًا لمسافة {n} متر. |  |  | ok |
| push.major-tsunami-warning | ja | Major Tsunami Warning | 大津波警報 | 大津波警報 |  |  | ok |
| push.major-tsunami-warning | zh-Hans | Major Tsunami Warning | 大海啸警报 | 大海啸警报 |  |  | ok |
| push.major-tsunami-warning | ko | Major Tsunami Warning | 대쓰나미 경보 | 대쓰나미 경보 |  |  | ok |
| push.major-tsunami-warning | ar | Major Tsunami Warning | تحذير من تسونامي كبير | تحذير من تسونامي عارم |  |  | ok |
| push.tsunami-warning | ja | Tsunami Warning | 津波警報 | 津波警報 |  |  | ok |
| push.tsunami-warning | zh-Hans | Tsunami Warning | 海啸警报 | 海啸警报 |  |  | ok |
| push.tsunami-warning | ko | Tsunami Warning | 쓰나미 경보 | 쓰나미경보 |  |  | ok |
| push.tsunami-warning | ar | Tsunami Warning | تحذير من تسونامي | تحذير من تسونامي |  |  | ok |
| push.tsunami-advisory | ja | Tsunami Advisory | 津波注意報 | 津波注意報 |  |  | ok |
| push.tsunami-advisory | zh-Hans | Tsunami Advisory | 海啸注意报 | 海啸注意报 |  |  | ok |
| push.tsunami-advisory | ko | Tsunami Advisory | 쓰나미 주의보 | 쓰나미 주의보 |  |  | ok |
| push.tsunami-advisory | ar | Tsunami Advisory | إشعار تسونامي | تنبيه من تسونامي |  |  | minor |
| push.cleared | ja | Tsunami alert lifted | 津波の警報・注意報は解除されました | 津波警報・注意報は解除されました |  |  | ok |
| push.cleared | zh-Hans | Tsunami alert lifted | 海啸警报已解除 | 海啸警报・注意报已解除 |  |  | ok |
| push.cleared | ko | Tsunami alert lifted | 쓰나미 경보가 해제되었습니다 | 쓰나미 경보·주의보가 해제되었습니다 |  |  | ok |
| push.cleared | ar | Tsunami alert lifted | تم رفع تنبيه التسونامي | تم إلغاء إنذار التسونامي |  |  | ok |
| push.cancelled | ja | Tsunami alert cancelled | 津波の情報は取り消されました | 津波警報・注意報は解除されました |  |  | minor |
| push.cancelled | zh-Hans | Tsunami alert cancelled | 海啸信息已取消 | 海啸警报已解除 |  |  | minor |
| push.cancelled | ko | Tsunami alert cancelled | 쓰나미 정보가 취소되었습니다 | 쓰나미 경보·주의보가 해제되었습니다 |  |  | minor |
| push.cancelled | ar | Tsunami alert cancelled | تم إلغاء تنبيه التسونامي | تم إلغاء إنذار التسونامي |  |  | ok |
| push.goNow | ja | Go uphill NOW | 今すぐ高台へ | 今すぐ高台へ避難してください！ |  |  | ok |
| push.goNow | zh-Hans | Go uphill NOW | 立即去高处 | 立刻往高处避难！ |  |  | ok |
| push.goNow | ko | Go uphill NOW | 지금 바로 높은 곳으로 | 지금 즉시 높은 곳으로 대피하십시오! |  |  | ok |
| push.goNow | ar | Go uphill NOW | اصعد إلى مكان مرتفع الآن | اذهب إلى مكان مرتفع الآن! |  |  | ok |
| push.advisory | ja | Get out of the water and away from the coast | 海から上がって、海岸から離れて | 海から上がり、海岸から離れてください。 |  |  | ok |
| push.advisory | zh-Hans | Get out of the water and away from the coast | 离开水中，远离海岸 | 立即离开水域并远离海岸。 |  |  | ok |
| push.advisory | ko | Get out of the water and away from the coast | 물에서 나와 해안에서 떨어지세요 | 바다에서 나와 해안에서 멀리 떨어지십시오. |  |  | ok |
| push.advisory | ar | Get out of the water and away from the coast | اخرج من الماء وابتعد عن الساحل | اخرجوا من المياه وابتعدوا عن الساحل. |  |  | ok |
| push.clearedBody | ja | Stay alert. Check official updates. | 引き続き注意してください。公式の情報を確認してください。 | 引き続き警戒し、公式情報を確認してください。 |  |  | ok |
| push.clearedBody | zh-Hans | Stay alert. Check official updates. | 请继续保持警惕，查看官方信息。 | 保持警惕。请关注官方信息。 |  |  | ok |
| push.clearedBody | ko | Stay alert. Check official updates. | 계속 주의하고 공식 정보를 확인하세요. | 계속 경계하십시오. 공식 정보를 확인하십시오. |  |  | ok |
| push.clearedBody | ar | Stay alert. Check official updates. | ابقَ متيقظًا وتحقق من التحديثات الرسمية. | ابقَ متيقظًا. تابع التحديثات الرسمية. |  |  | ok |
| push.upgrade | ja | Upgraded | 格上げ | 引き上げ |  |  | ok |
| push.upgrade | zh-Hans | Upgraded | 已升级 | 升级 |  |  | ok |
| push.upgrade | ko | Upgraded | 격상 | 격상 |  |  | ok |
| push.upgrade | ar | Upgraded | تم الرفع | تمت الترقية |  |  | ok |
| push.raise | ja | Height raised | 高さの引き上げ | 高さ引き上げ |  |  | ok |
| push.raise | zh-Hans | Height raised | 高度已上调 | 高度上调 |  |  | ok |
| push.raise | ko | Height raised | 높이 상향 | 높이 상향 |  |  | ok |
| push.raise | ar | Height raised | تم رفع الارتفاع | تم رفع الارتفاع |  |  | ok |
| push.height | ja | Expected height | 予想される高さ | 予想される高さ |  |  | ok |
| push.height | zh-Hans | Expected height | 预计高度 | 预测高度 |  |  | ok |
| push.height | ko | Expected height | 예상 높이 | 예상 높이 |  |  | ok |
| push.height | ar | Expected height | الارتفاع المتوقع | الارتفاع المتوقع |  |  | ok |
| push.huge | ja | Huge | 巨大 | 巨大 |  |  | ok |
| push.huge | zh-Hans | Huge | 巨大 | 巨大 |  |  | ok |
| push.huge | ko | Huge | 거대 | 거대 |  |  | ok |
| push.huge | ar | Huge | هائل | ضخمة |  |  | ok |
| push.high | ja | High | 高い | 高い |  |  | ok |
| push.high | zh-Hans | High | 高 | 高 |  |  | ok |
| push.high | ko | High | 높음 | 높음 |  |  | ok |
| push.high | ar | High | مرتفع | مرتفع |  |  | ok |
| commonStrings.simulatedAlert | ja | SIMULATED ALERT | 模擬アラート | 訓練警報 |  |  | minor |
| commonStrings.simulatedAlert | zh-Hans | SIMULATED ALERT | 模拟警报 | 模拟警报 |  |  | ok |
| commonStrings.simulatedAlert | ko | SIMULATED ALERT | 모의 경보 | 훈련 경보 |  |  | ok |
| commonStrings.simulatedAlert | ar | SIMULATED ALERT | تنبيه تجريبي | إنذار محاكاة |  |  | ok |
| commonStrings.onHighGround | ja | On high ground | 高台に着いた | 高台に避難中 |  |  | minor |
| commonStrings.onHighGround | zh-Hans | On high ground | 已到高处 | 已在高处 |  |  | minor |
| commonStrings.onHighGround | ko | On high ground | 고지대 도착 | 고지대에 있음 |  |  | minor |
| commonStrings.onHighGround | ar | On high ground | وصلت إلى مكان مرتفع | على أرض مرتفعة |  |  | minor |
| commonStrings.shakingStopped | ja | Shaking stopped | 揺れがおさまった | 揺れが収まりました |  |  | ok |
| commonStrings.shakingStopped | zh-Hans | Shaking stopped | 摇晃已停止 | 摇晃已停止 |  |  | ok |
| commonStrings.shakingStopped | ko | Shaking stopped | 흔들림 멈춤 | 흔들림 멈춤 |  |  | ok |
| commonStrings.shakingStopped | ar | Shaking stopped | توقف الاهتزاز | توقف الاهتزاز |  |  | ok |
| commonStrings.emergencyCall | ja | Emergency call | 緊急通報 | 緊急通報 |  |  | ok |
| commonStrings.emergencyCall | zh-Hans | Emergency call | 紧急电话 | 紧急呼叫 |  |  | ok |
| commonStrings.emergencyCall | ko | Emergency call | 긴급 전화 | 긴급 전화 |  |  | ok |
| commonStrings.emergencyCall | ar | Emergency call | اتصال طوارئ | اتصال طوارئ |  |  | ok |
| commonStrings.evacuationMap | ja | Evacuation map | 避難マップ | 避難マップ |  |  | ok |
| commonStrings.evacuationMap | zh-Hans | Evacuation map | 避难地图 | 避难地图 |  |  | ok |
| commonStrings.evacuationMap | ko | Evacuation map | 대피 지도 | 대피 지도 |  |  | ok |
| commonStrings.evacuationMap | ar | Evacuation map | خريطة الإخلاء | خريطة الإخلاء |  |  | ok |
| commonStrings.badgeEarthquake | ja | EARTHQUAKE | 地震 | 地震 |  |  | ok |
| commonStrings.badgeEarthquake | zh-Hans | EARTHQUAKE | 地震 | 地震 |  |  | ok |
| commonStrings.badgeEarthquake | ko | EARTHQUAKE | 지진 | 지진 |  |  | ok |
| commonStrings.badgeEarthquake | ar | EARTHQUAKE | زلزال | زلزال |  |  | ok |
| commonStrings.badgeTsunami | ja | TSUNAMI | 津波 | 津波 |  |  | ok |
| commonStrings.badgeTsunami | zh-Hans | TSUNAMI | 海啸 | 海啸 |  |  | ok |
| commonStrings.badgeTsunami | ko | TSUNAMI | 쓰나미 | 쓰나미 |  |  | ok |
| commonStrings.badgeTsunami | ar | TSUNAMI | تسونامي | تسونامي |  |  | ok |
| commonStrings.badgeTsunamiAdvisory | ja | TSUNAMI ADVISORY | 津波注意報 | 津波注意報 |  |  | ok |
| commonStrings.badgeTsunamiAdvisory | zh-Hans | TSUNAMI ADVISORY | 海啸注意报 | 海啸注意报 |  |  | ok |
| commonStrings.badgeTsunamiAdvisory | ko | TSUNAMI ADVISORY | 쓰나미 주의보 | 지진해일주의보 |  |  | minor |
| commonStrings.badgeTsunamiAdvisory | ar | TSUNAMI ADVISORY | إشعار تسونامي | تنبيه من تسونامي |  |  | minor |
| commonStrings.badgeTsunamiWarning | ja | TSUNAMI WARNING | 津波警報 | 津波警報 |  |  | ok |
| commonStrings.badgeTsunamiWarning | zh-Hans | TSUNAMI WARNING | 海啸警报 | 海啸警报 |  |  | ok |
| commonStrings.badgeTsunamiWarning | ko | TSUNAMI WARNING | 쓰나미 경보 | 지진해일 경보 |  |  | minor |
| commonStrings.badgeTsunamiWarning | ar | TSUNAMI WARNING | تحذير تسونامي | إنذار من التسونامي |  |  | ok |
| commonStrings.badgeMajorTsunamiWarning | ja | MAJOR TSUNAMI WARNING | 大津波警報 | 大津波警報 |  |  | ok |
| commonStrings.badgeMajorTsunamiWarning | zh-Hans | MAJOR TSUNAMI WARNING | 大海啸警报 | 大海啸警报 |  |  | ok |
| commonStrings.badgeMajorTsunamiWarning | ko | MAJOR TSUNAMI WARNING | 대형 쓰나미 경보 | 대쓰나미경보 |  |  | minor |
| commonStrings.badgeMajorTsunamiWarning | ar | MAJOR TSUNAMI WARNING | تحذير تسونامي كبير | تحذير من تسونامي عارم |  |  | ok |
| commonStrings.badgeTsunamiWarningActive | ja | TSUNAMI WARNING ACTIVE | 津波警報 発表中 | 津波警報発表中 |  |  | ok |
| commonStrings.badgeTsunamiWarningActive | zh-Hans | TSUNAMI WARNING ACTIVE | 海啸警报生效中 | 海啸警报生效中 |  |  | ok |
| commonStrings.badgeTsunamiWarningActive | ko | TSUNAMI WARNING ACTIVE | 쓰나미 경보 발령 중 | 쓰나미 경보 발령 중 |  |  | ok |
| commonStrings.badgeTsunamiWarningActive | ar | TSUNAMI WARNING ACTIVE | تحذير تسونامي ساري | تحذير من تسونامي نشط |  |  | ok |
| commonStrings.badgeIndoors | ja | INDOORS | 屋内 | 屋内 |  |  | ok |
| commonStrings.badgeIndoors | zh-Hans | INDOORS | 室内 | 室内 |  |  | ok |
| commonStrings.badgeIndoors | ko | INDOORS | 실내 | 실내 |  |  | ok |
| commonStrings.badgeIndoors | ar | INDOORS | في الداخل | داخل المبنى |  |  | ok |
| commonStrings.badgeOutdoors | ja | OUTDOORS | 屋外 | 屋外 |  |  | ok |
| commonStrings.badgeOutdoors | zh-Hans | OUTDOORS | 室外 | 户外 |  |  | ok |
| commonStrings.badgeOutdoors | ko | OUTDOORS | 실외 | 야외 |  |  | ok |
| commonStrings.badgeOutdoors | ar | OUTDOORS | في الخارج | في الخارج |  |  | ok |
| commonStrings.badgeInCar | ja | IN CAR | 車内 | 車内 |  |  | ok |
| commonStrings.badgeInCar | zh-Hans | IN CAR | 车内 | 车内 |  |  | ok |
| commonStrings.badgeInCar | ko | IN CAR | 차 안 | 차량 내 |  |  | ok |
| commonStrings.badgeInCar | ar | IN CAR | في السيارة | داخل السيارة |  |  | ok |
| commonStrings.badgeLocationUncertain | ja | LOCATION UNCERTAIN | 位置が不確か | 位置不明 |  |  | ok |
| commonStrings.badgeLocationUncertain | zh-Hans | LOCATION UNCERTAIN | 位置不确定 | 位置不明 |  |  | ok |
| commonStrings.badgeLocationUncertain | ko | LOCATION UNCERTAIN | 위치 불확실 | 위치 불확실 |  |  | ok |
| commonStrings.badgeLocationUncertain | ar | LOCATION UNCERTAIN | الموقع غير مؤكد | الموقع غير محدد |  |  | ok |
| commonStrings.levelAdvisory | ja | Advisory | 注意報 | 注意報 |  |  | ok |
| commonStrings.levelAdvisory | zh-Hans | Advisory | 注意报 | 注意报 |  |  | ok |
| commonStrings.levelAdvisory | ko | Advisory | 주의보 | 주의보 |  |  | ok |
| commonStrings.levelAdvisory | ar | Advisory | إشعار | تحذير |  |  | minor |
| commonStrings.levelWarning | ja | Warning | 警報 | 警報 |  |  | ok |
| commonStrings.levelWarning | zh-Hans | Warning | 警报 | 警报 |  |  | ok |
| commonStrings.levelWarning | ko | Warning | 경보 | 경보 |  |  | ok |
| commonStrings.levelWarning | ar | Warning | تحذير | تحذير |  |  | ok |
| commonStrings.levelEmergency | ja | Emergency warning | 特別警報 | 特別警報 |  |  | ok |
| commonStrings.levelEmergency | zh-Hans | Emergency warning | 特别警报 | 特别警报 |  |  | ok |
| commonStrings.levelEmergency | ko | Emergency warning | 특별경보 | 특별경보 |  |  | ok |
| commonStrings.levelEmergency | ar | Emergency warning | تحذير طارئ | تحذير طوارئ |  |  | ok |
| commonStrings.warningActive | ja | Warning active | 警報 発表中 | 警報発表中 |  |  | ok |
| commonStrings.warningActive | zh-Hans | Warning active | 警报生效中 | 警报生效中 |  |  | ok |
| commonStrings.warningActive | ko | Warning active | 경보 발령 중 | 경보 발령 중 |  |  | ok |
| commonStrings.warningActive | ar | Warning active | التحذير ساري | التحذير نشط |  |  | ok |
| commonStrings.routeGuidancePaused | ja | Route guidance paused | ルート案内を一時停止中 | ルート案内一時停止中 |  |  | ok |
| commonStrings.routeGuidancePaused | zh-Hans | Route guidance paused | 路线导航已暂停 | 路线导航已暂停 |  |  | ok |
| commonStrings.routeGuidancePaused | ko | Route guidance paused | 경로 안내 일시정지 | 경로 안내 일시 중지 |  |  | ok |
| commonStrings.routeGuidancePaused | ar | Route guidance paused | إرشاد المسار متوقف مؤقتًا | إيقاف إرشاد الطريق مؤقتًا |  |  | ok |
| commonStrings.routeUnverified | ja | Route unverified | ルート未確認 | ルート未確認 |  |  | ok |
| commonStrings.routeUnverified | zh-Hans | Route unverified | 路线未确认 | 路线未确认 |  |  | ok |
| commonStrings.routeUnverified | ko | Route unverified | 경로 미확인 | 경로 미확인 |  |  | ok |
| commonStrings.routeUnverified | ar | Route unverified | المسار غير مؤكد | مسار غير مؤكد |  |  | ok |
| commonStrings.liveRoadUnavailable | ja | Live road status unavailable | 道路の最新状況は取得できません | リアルタイムの道路状況は利用できません |  |  | ok |
| commonStrings.liveRoadUnavailable | zh-Hans | Live road status unavailable | 无法获取实时路况 | 实时路况不可用 |  |  | ok |
| commonStrings.liveRoadUnavailable | ko | Live road status unavailable | 실시간 도로 정보 없음 | 실시간 도로 상황 이용 불가 |  |  | ok |
| commonStrings.liveRoadUnavailable | ar | Live road status unavailable | حالة الطرق المباشرة غير متاحة | حالة الطرق المباشرة غير متوفرة |  |  | ok |
| commonStrings.highGround | ja | HIGH GROUND | 高台 | 高台 |  |  | ok |
| commonStrings.highGround | zh-Hans | HIGH GROUND | 高地 | 高地 |  |  | ok |
| commonStrings.highGround | ko | HIGH GROUND | 고지대 | 고지대 |  |  | ok |
| commonStrings.highGround | ar | HIGH GROUND | مكان مرتفع | أرض مرتفعة |  |  | ok |
| commonStrings.left | ja | Left | 左 | 左 |  |  | ok |
| commonStrings.left | zh-Hans | Left | 左转 | 左 |  |  | ok |
| commonStrings.left | ko | Left | 왼쪽 | 왼쪽 |  |  | ok |
| commonStrings.left | ar | Left | يسار | يسار |  |  | ok |
| commonStrings.right | ja | Right | 右 | 右 |  |  | ok |
| commonStrings.right | zh-Hans | Right | 右转 | 右 |  |  | ok |
| commonStrings.right | ko | Right | 오른쪽 | 오른쪽 |  |  | ok |
| commonStrings.right | ar | Right | يمين | يمين |  |  | ok |
| commonStrings.straight | ja | Straight | 直進 | 直進 |  |  | ok |
| commonStrings.straight | zh-Hans | Straight | 直行 | 直行 |  |  | ok |
| commonStrings.straight | ko | Straight | 직진 | 직진 |  |  | ok |
| commonStrings.straight | ar | Straight | إلى الأمام | مستقيم |  |  | ok |
| s11.turnAround | ja | Turn around | 後ろを向いてください | 後ろを向いて |  |  | ok |
| s11.turnAround | zh-Hans | Turn around | 请向后转 | 向后转 |  |  | ok |
| s11.turnAround | ko | Turn around | 뒤로 도세요 | 뒤로 도세요 |  |  | ok |
| s11.turnAround | ar | Turn around | استدر للخلف | استدر للخلف |  |  | ok |

## 読み方

- 判定 major: 意味・緊急度・公式の用語が違う、または誤解を招くおそれ。minor: 通じるが言い回しや用語を直せる。ok: 問題なし
- プレースホルダー（`{n}` など）が原文と合わない訳は、Gemini の判定にかかわらず major にしている
- 再実行: `node tools/i18n-check/check.mjs`（キャッシュが効くので、文を変えなければ API は呼ばない）
