// UI strings in the 5 languages of the mock (mocks/evacuate/src/i18n). Strings shared with the mock use
// the mock's wording; the AR-paused reasons are new (demo translations, not native-checked).
import 'guide_params.dart';

class S {
  const S({
    required this.title,
    required this.tsunamiWarning,
    required this.arPaused,
    required this.demo,
    required this.map,
    required this.left,
    required this.right,
    required this.straight,
    required this.meters,
    required this.checkLocation,
    required this.calibrateCompass,
    required this.figure8,
    required this.pointAtFloor,
    required this.uncertain,
    required this.tooDark,
    required this.tooFast,
    required this.noFeatures,
    required this.noCompass,
    required this.cameraOff,
    required this.cameraError,
    required this.starting,
    required this.allowCamera,
    required this.openSettings,
    required this.back,
    required this.routeHidden,
    required this.stripedHazard,
    required this.modeCompass,
    required this.modeArcore,
    required this.lowAccuracy,
    required this.turnAround,
  });

  final String title;
  final String tsunamiWarning;
  final String arPaused;
  final String demo;
  final String map;
  final String left;
  final String right;
  final String straight;

  /// "{n} m"
  final String meters;
  final String checkLocation;
  final String calibrateCompass;
  final String figure8;
  final String pointAtFloor;
  final String uncertain;
  final String tooDark;
  final String tooFast;
  final String noFeatures;
  final String noCompass;
  final String cameraOff;
  final String cameraError;
  final String starting;
  final String allowCamera;
  final String openSettings;
  final String back;
  final String routeHidden;
  final String stripedHazard;
  final String modeCompass;
  final String modeArcore;

  /// Small note when the compass accuracy is LOW (arrow still shown).
  final String lowAccuracy;

  /// The route is behind the user (same wording as the mock's S11).
  final String turnAround;

  String turn(Turn t) => switch (t) {
        Turn.left => left,
        Turn.right => right,
        Turn.straight => straight,
      };

  String distance(int m) => meters.replaceAll('{n}', '$m');

  static S of(Lang lang) => switch (lang) {
        Lang.en => _en,
        Lang.ja => _ja,
        Lang.zhHans => _zh,
        Lang.ko => _ko,
        Lang.ar => _ar,
      };
}

const _en = S(
  title: 'AR guidance',
  tsunamiWarning: 'TSUNAMI WARNING',
  arPaused: 'AR PAUSED',
  demo: 'DEMO',
  map: 'MAP',
  left: 'Left',
  right: 'Right',
  straight: 'Straight',
  meters: '{n} m',
  checkLocation: 'Check location',
  calibrateCompass: 'Calibrate compass',
  figure8: 'Move your phone in a figure 8 a few times',
  pointAtFloor: 'Point the camera at the floor and move slowly',
  uncertain: 'Camera position uncertain',
  tooDark: 'Too dark for the camera',
  tooFast: 'Moving too fast. Hold the phone steady',
  noFeatures: 'Point the camera at a surface with more detail',
  noCompass: 'This phone has no compass sensor',
  cameraOff: 'Camera access is off',
  cameraError: 'The camera is not available',
  starting: 'Starting the camera…',
  allowCamera: 'Allow camera',
  openSettings: 'Open settings',
  back: 'Back to map',
  routeHidden: 'Route arrows hidden',
  stripedHazard: 'Striped = hazard',
  modeCompass: 'Compass',
  modeArcore: 'ARCore',
  lowAccuracy: 'Compass accuracy low',
  turnAround: 'Turn around',
);

const _ja = S(
  title: 'AR 案内',
  tsunamiWarning: '津波警報',
  arPaused: 'AR 停止中',
  demo: 'デモ',
  map: '地図',
  left: '左',
  right: '右',
  straight: '直進',
  meters: '{n} m',
  checkLocation: '現在地を確認',
  calibrateCompass: '方位を補正',
  figure8: 'スマートフォンを 8 の字に数回動かしてください',
  pointAtFloor: 'カメラを床に向けて、ゆっくり動かしてください',
  uncertain: 'カメラの位置が不確かです',
  tooDark: '暗すぎてカメラで認識できません',
  tooFast: '動きが速すぎます。端末を止めてください',
  noFeatures: '模様のある面にカメラを向けてください',
  noCompass: 'この端末には方位センサーがありません',
  cameraOff: 'カメラの使用が許可されていません',
  cameraError: 'カメラを使えません',
  starting: 'カメラを起動中…',
  allowCamera: 'カメラを許可',
  openSettings: '設定を開く',
  back: '地図に戻る',
  routeHidden: '経路の矢印を非表示中',
  stripedHazard: '斜線 = 危険区域',
  modeCompass: 'コンパス',
  modeArcore: 'ARCore',
  lowAccuracy: '方位の精度低',
  turnAround: '後ろを向いてください',
);

const _zh = S(
  title: 'AR 导航',
  tsunamiWarning: '海啸警报',
  arPaused: 'AR 已暂停',
  demo: '演示',
  map: '地图',
  left: '左转',
  right: '右转',
  straight: '直行',
  meters: '{n} 米',
  checkLocation: '确认位置',
  calibrateCompass: '校准指南针',
  figure8: '请将手机按 8 字形移动几次',
  pointAtFloor: '请将相机对准地面并缓慢移动',
  uncertain: '相机位置不确定',
  tooDark: '光线太暗，相机无法识别',
  tooFast: '移动过快，请保持手机稳定',
  noFeatures: '请将相机对准有纹理的表面',
  noCompass: '此手机没有指南针传感器',
  cameraOff: '未允许使用相机',
  cameraError: '相机不可用',
  starting: '正在启动相机…',
  allowCamera: '允许相机',
  openSettings: '打开设置',
  back: '返回地图',
  routeHidden: '已隐藏路线箭头',
  stripedHazard: '斜线 = 危险区域',
  modeCompass: '指南针',
  modeArcore: 'ARCore',
  lowAccuracy: '指南针精度低',
  turnAround: '请向后转',
);

const _ko = S(
  title: 'AR 안내',
  tsunamiWarning: '쓰나미 경보',
  arPaused: 'AR 일시정지',
  demo: '데모',
  map: '지도',
  left: '왼쪽',
  right: '오른쪽',
  straight: '직진',
  meters: '{n} m',
  checkLocation: '위치 확인',
  calibrateCompass: '나침반 보정',
  figure8: '휴대폰을 8자 모양으로 몇 번 움직이세요',
  pointAtFloor: '카메라를 바닥에 향하고 천천히 움직이세요',
  uncertain: '카메라 위치가 불확실합니다',
  tooDark: '너무 어두워 카메라가 인식할 수 없습니다',
  tooFast: '너무 빠르게 움직이고 있습니다. 휴대폰을 고정하세요',
  noFeatures: '무늬가 있는 표면에 카메라를 향하세요',
  noCompass: '이 휴대폰에는 나침반 센서가 없습니다',
  cameraOff: '카메라 사용이 허용되지 않았습니다',
  cameraError: '카메라를 사용할 수 없습니다',
  starting: '카메라 시작 중…',
  allowCamera: '카메라 허용',
  openSettings: '설정 열기',
  back: '지도로 돌아가기',
  routeHidden: '경로 화살표 숨김',
  stripedHazard: '빗금 = 위험 구역',
  modeCompass: '나침반',
  modeArcore: 'ARCore',
  lowAccuracy: '나침반 정확도 낮음',
  turnAround: '뒤로 도세요',
);

const _ar = S(
  title: 'إرشاد الواقع المعزز',
  tsunamiWarning: 'تحذير تسونامي',
  arPaused: 'الواقع المعزز متوقف',
  demo: 'عرض تجريبي',
  map: 'الخريطة',
  left: 'يسار',
  right: 'يمين',
  straight: 'إلى الأمام',
  meters: '{n} م',
  checkLocation: 'تحقق من الموقع',
  calibrateCompass: 'معايرة البوصلة',
  figure8: 'حرّك هاتفك على شكل الرقم 8 عدة مرات',
  pointAtFloor: 'وجّه الكاميرا نحو الأرض وتحرك ببطء',
  uncertain: 'موضع الكاميرا غير مؤكد',
  tooDark: 'المكان مظلم جدًا للكاميرا',
  tooFast: 'الحركة سريعة جدًا. ثبّت الهاتف',
  noFeatures: 'وجّه الكاميرا نحو سطح أكثر تفصيلًا',
  noCompass: 'لا يحتوي هذا الهاتف على مستشعر بوصلة',
  cameraOff: 'الوصول إلى الكاميرا متوقف',
  cameraError: 'الكاميرا غير متاحة',
  starting: 'جارٍ تشغيل الكاميرا…',
  allowCamera: 'السماح بالكاميرا',
  openSettings: 'فتح الإعدادات',
  back: 'العودة إلى الخريطة',
  routeHidden: 'أسهم المسار مخفية',
  stripedHazard: 'المخطط = منطقة خطر',
  modeCompass: 'البوصلة',
  modeArcore: 'ARCore',
  lowAccuracy: 'دقة البوصلة منخفضة',
  turnAround: 'استدر للخلف',
);
