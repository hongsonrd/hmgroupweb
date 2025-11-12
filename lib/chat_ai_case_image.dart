// Image Mode Preset Cases
// These presets provide quick access to common image analysis tasks

import 'package:flutter/material.dart';
import 'dart:math';

// Generate a random vibrant color for preset glow
Color _generatePresetColor(int seed) {
  final random = Random(seed);
  final hue = random.nextDouble() * 360; // Random hue 0-360
  final saturation = 0.6 + random.nextDouble() * 0.3; // 0.6-0.9 saturation
  final value = 0.7 + random.nextDouble() * 0.3; // 0.7-1.0 brightness

  return HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
}

class ImagePreset {
  final String id;
  final String name;
  final String description;
  final String hiddenPrompt;
  final String modelId;
  final Color glowColor;

  ImagePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.hiddenPrompt,
    required this.modelId,
    Color? glowColor,
  }) : glowColor = glowColor ?? _generatePresetColor(id.hashCode);
}

// List of preset image analysis cases
final List<ImagePreset> imagePresets = [
ImagePreset(
id:'a017',
name: 'Hai người trong thang máy',
description: 'Vui lòng chọn 2 ảnh rõ mặt từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Maintain the same subjects from Figures 1 on the left half and 2 on the right half,Two fashionable people from uploaded photos standing close together inside a modern silver elevator with smooth metallic walls. Captured from a high angle, they look up at the camera with confident, intense expressions. luxurious texture. creating clean reflections and a cinematic, stylish atmosphere, with only the reflective silver metal elevator as the background.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a019',
name: 'Đến Pari, tháp Eifel',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Please draw an extremely ordinary and unremarkable iPhone selfie, with no clear subject or sense of composition — just like a random snapshot taken casually. The photo should include slight motion blur, with uneven lighting caused by sunlight or indoor lights resulting in mild overexposure. The angle is awkward, the composition is messy, and the overall aesthetic is deliberately plain — as if it was accidentally taken while pulling the phone out of a pocket. The subject is Figure in attached image, taken at night, next to the Eiffel tower.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a001',
name: 'Tạo mô hình 3D từ ảnh của bạn',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Convert the uploaded 2D photo of the person into a 1/7 scale PVC figure render inside a clear acrylic showcase box with realistic PVC textures, painted finish, simple round black base, natural daylight lighting, original street background, full-body view at 20° left, and slight blur/noise as if photographed with a real camera.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a002',
name: 'Tạo ảnh hộ chiếu',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Passport/visa-style portrait: dress the subject in a dark suit with white shirt and simple tie; plain white background; neutral expression; head centered; crop 35×45 mm; add a uniform 3 mm white border; no face reshaping',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a003',
name: 'Phục chế ảnh cũ/ xấu',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Clean restore: remove scratches/dust and JPEG artifacts, gentle denoise → mild deblur, fix color cast to neutral; preserve natural skin texture (no beautify), avoid halos; output crisp and photoreal.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a004',
name: 'Tạo thành nhân vật trong game cổ điển',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform your image into a 16-bit classic RPG game screen. Express it with pixel art style, town/forest/dungeon backgrounds, HP/MP UI, and NPC dialogue boxes.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a005',
name: 'Biến thành chương trình TV',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform this image into a 1990s sitcom filming scene. Include a bright indoor set, a laugh-track indicator, and a VHS screen texture.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a006',
name: 'Vào trong thế giới thần tiên',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform your image into an illustration from a fairy tale book. Include pastel tones, watercolor texture, cute and exaggerated characters, paper book texture, and handwritten-style captions.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a007',
name: 'Biến thành bài báo',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform this image to look like a 90s hologram card. Express a metallic shimmer, rainbow patterns, and an effect that changes with the viewing angle.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a008',
name: 'Vào trong thế giới thực tế ảo',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform this image into a scene from an augmented reality game. Display a health bar, quest icon, and map UI above the character, and express a futuristic atmosphere where reality and digital overlap in the background.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a009',
name: 'Biến thành thẻ bài',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform this image to look like a 90s hologram card. Express a metallic shimmer, rainbow patterns, and an effect that changes with the viewing angle.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a010',
name: 'Biến thành tranh thuỷ mặc',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform this image into a traditional ink wash painting style. Capture the character expressed concisely and elegantly amidst a landscape background, utilizing shades of ink and the beauty of empty space.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a011',
name: 'Biến thành board game',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform this image to look like a board game. Represent the character as a token, and design the background as a board with square spaces, dice, and scattered cards.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a012',
name: 'Biến thành tranh cổ Aztec',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform this image into a Mexican Aztec mural style. Include bold lines, geometric patterns, a color scheme centered on red and gold, and mythological gods and totem elements.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a013',
name: 'Biến thành game 2D cel',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform this image into a modern animation cel-shading style. Direct it as a cartoon-like illustration with clean lines, flat colors, and highlights and shadows rendered in simple blocks.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a014',
name: 'Biến thành tranh mini Ấn Độ',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform this image into an Indian miniature painting style. Express ornate decorations, a color palette centered on gold and primary colors, and delicate patterns with mythological animals in the background.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a015',
name: 'Biến thành tranh khắc',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform this image into a classic etching style. Use detailed black-and-white line art, dense hatching for shading, and an antique print texture.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a016',
name: 'Biến thành tranh vẽ tay',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Transform this image to look like a doodle sketchbook. Express it with rough lines as if drawn with pencil and pen, overlapping line art in the margins, and a lively, chaotic feel of scribbled notes or speech bubbles.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a018',
name: 'Trở thành búp bê len',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'A close-up, professionally composed photograph showcasing a hand-crocheted yarn doll gently cradled by two hands. The doll has a rounded shape, featuring the cute chibi image of the [upload image] character, with vivid contrasting colors and rich details. The hands holding the doll are natural and gentle, with clearly visible finger postures, and natural skin texture and light/shadow transitions, conveying a warm and realistic touch. The background is slightly blurred, depicting an indoor environment with a warm wooden tabletop and natural light streaming in from a window, creating a comfortable and intimate atmosphere. The overall image conveys a sense of exquisite craftsmanship and cherished warmth.',
modelId: 'flash-2.5-image', ),
ImagePreset(
id:'a020',
name: '1 ảnh thành 9 ảnh',
description: 'Vui lòng chọn 1 ảnh từ nút thêm ảnh bên dưới rồi bấm gửi',
hiddenPrompt: 'Turn the photo into a 3x3 grid of photo strips with different studio-style poses and expressions.',
modelId: 'flash-2.5-image', ),
];
