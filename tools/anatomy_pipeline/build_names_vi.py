#!/usr/bin/env python3
"""Builds assets/anatomy/names_vi.json: part id -> Vietnamese name.

Names in parts.json are English (FMA / BodyParts3D). They are translated with
a curated dictionary of Vietnamese anatomical terms (as used in Vietnamese
anatomy textbooks, e.g. "Giải phẫu học" - Đại học Y Hà Nội) and a few
composition rules (sides, ordinals, "part of X", "artery/vein of X").

A name is only emitted when every word of it is understood; anything else is
left out so the app falls back to the English name rather than a guess.

Usage: python3 tools/anatomy_pipeline/build_names_vi.py
"""

import collections
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
PARTS = os.path.join(ROOT, 'assets', 'anatomy', 'parts.json')
OUT = os.path.join(ROOT, 'assets', 'anatomy', 'names_vi.json')

SIDE = {'left': 'trái', 'right': 'phải'}

ORDINAL = {
    'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'fifth': 5, 'sixth': 6,
    'seventh': 7, 'eighth': 8, 'ninth': 9, 'tenth': 10, 'eleventh': 11, 'twelfth': 12,
}
# "thứ nhất", "thứ hai"… as written after a noun.
ORDINAL_WORD = {
    1: 'thứ nhất', 2: 'thứ hai', 3: 'thứ ba', 4: 'thứ tư', 5: 'thứ năm', 6: 'thứ sáu',
    7: 'thứ bảy', 8: 'thứ tám', 9: 'thứ chín', 10: 'thứ mười', 11: 'thứ mười một',
    12: 'thứ mười hai',
}
ORD_RE = '|'.join(ORDINAL)

# ---------------------------------------------------------------------------
# Whole names (side removed, lower case) -> Vietnamese (lower-case initial).
# ---------------------------------------------------------------------------
TERMS = {
    # --- Skeleton: skull ---
    'frontal bone': 'xương trán',
    'occipital bone': 'xương chẩm',
    'sphenoid bone': 'xương bướm',
    'ethmoid': 'xương sàng',
    'mandible': 'xương hàm dưới',
    'vomer': 'xương lá mía',
    'hyoid bone': 'xương móng',
    'parietal bone': 'xương đỉnh',
    'temporal bone': 'xương thái dương',
    'zygomatic bone': 'xương gò má',
    'nasal bone': 'xương mũi',
    'lacrimal bone': 'xương lệ',
    'palatine bone': 'xương khẩu cái',
    'maxilla': 'xương hàm trên',
    'inferior nasal concha': 'xương xoăn mũi dưới',
    # --- Skeleton: trunk ---
    'atlas': 'đốt đội (đốt sống cổ 1)',
    'axis': 'đốt trục (đốt sống cổ 2)',
    'sacrum': 'xương cùng',
    'manubrium': 'cán xương ức',
    'body of sternum': 'thân xương ức',
    'xiphoid process': 'mỏm mũi kiếm',
    'intervertebral disk': 'đĩa gian đốt sống',
    'intervertebral disk of axis': 'đĩa gian đốt sống cổ 2',
    # --- Skeleton: limbs ---
    'clavicle': 'xương đòn',
    'scapula': 'xương vai',
    'humerus': 'xương cánh tay',
    'radius': 'xương quay',
    'ulna': 'xương trụ',
    'hip bone': 'xương chậu',
    'femur': 'xương đùi',
    'patella': 'xương bánh chè',
    'tibia': 'xương chày',
    'fibula': 'xương mác',
    'scaphoid': 'xương thuyền',
    'lunate': 'xương nguyệt',
    'triquetral': 'xương tháp',
    'pisiform': 'xương đậu',
    'trapezium': 'xương thang',
    'trapezoid': 'xương thê',
    'capitate': 'xương cả',
    'hamate': 'xương móc',
    'talus': 'xương sên',
    'calcaneus': 'xương gót',
    'cuboid bone': 'xương hộp',
    'medial cuneiform bone': 'xương chêm trong',
    'intermediate cuneiform bone': 'xương chêm giữa',
    'lateral cuneiform bone': 'xương chêm ngoài',
    'navicular bone of foot': 'xương ghe',
    'sesamoid bone of foot': 'xương vừng bàn chân',
    # --- Cartilages and ligaments ---
    'cricoid cartilage': 'sụn nhẫn',
    'thyroid cartilage': 'sụn giáp',
    'arytenoid cartilage': 'sụn phễu',
    'corniculate cartilage': 'sụn sừng',
    'cuneiform cartilage': 'sụn chêm thanh quản',
    'septal nasal cartilage': 'sụn vách mũi',
    'lateral nasal cartilage': 'sụn mũi bên',
    'major alar cartilage': 'sụn cánh mũi lớn',
    'hyo-epiglottic ligament': 'dây chằng móng - nắp thanh môn',
    'thyro-epiglottic ligament': 'dây chằng giáp - nắp thanh môn',
    'median thyrohyoid ligament': 'dây chằng giáp - móng giữa',
    'lateral thyrohyoid ligament': 'dây chằng giáp - móng bên',
    'stylohyoid ligament': 'dây chằng trâm - móng',
    'long plantar ligament': 'dây chằng gan chân dài',
    'trochlea of superior oblique': 'ròng rọc cơ chéo trên',

    # --- Digestive ---
    'stomach': 'dạ dày',
    'gallbladder': 'túi mật',
    'pancreas': 'tụy',
    'duodenum': 'tá tràng',
    'rectum': 'trực tràng',
    'esophagus': 'thực quản',
    'appendix': 'ruột thừa',
    'ascending colon': 'đại tràng lên',
    'transverse colon': 'đại tràng ngang',
    'descending colon': 'đại tràng xuống',
    'caudate lobe of liver': 'thùy đuôi gan',
    'ileum': 'hồi tràng',
    'jejunum': 'hỗng tràng',
    'ileocecal junction': 'chỗ nối hồi - manh tràng',
    'mesentery of small intestine': 'mạc treo ruột non',
    'mesoappendix': 'mạc treo ruột thừa',
    'transverse mesocolon': 'mạc treo đại tràng ngang',
    'taenia libera': 'dải cơ dọc tự do',
    'taenia mesocolica': 'dải cơ dọc mạc treo',
    'taenia omentalis': 'dải cơ dọc mạc nối',
    'tongue': 'lưỡi',
    'gingiva of upper jaw': 'lợi hàm trên',
    'gingiva of lower jaw': 'lợi hàm dưới',
    'sublingual gland': 'tuyến dưới lưỡi',
    'submandibular gland': 'tuyến dưới hàm',
    'common hepatic duct': 'ống gan chung',
    'cystic duct': 'ống túi mật',
    'pancreatic duct': 'ống tụy',
    'pancreatic duct tree': 'cây ống tụy',
    'parenchyma of pancreas': 'nhu mô tụy',
    'hepatic duct': 'ống gan',

    # --- Respiratory ---
    'trachea': 'khí quản',
    'epiglottis': 'nắp thanh môn',
    'main bronchus': 'phế quản chính',
    'main bronchus proper': 'phế quản chính',
    'thyrohyoid membrane': 'màng giáp - móng',
    'vocal ligament': 'dây chằng thanh âm',
    'conus elasticus': 'nón đàn hồi',
    'median cricothyroid ligament': 'dây chằng nhẫn - giáp giữa',

    # --- Urinary / reproductive / endocrine / skin ---
    'kidney': 'thận',
    'ureter': 'niệu quản',
    'urethra': 'niệu đạo',
    'urinary bladder': 'bàng quang',
    'corpus cavernosum of penis': 'vật hang dương vật',
    'corpus spongiosum of penis': 'vật xốp dương vật',
    'glans penis': 'quy đầu dương vật',
    'deferent duct': 'ống dẫn tinh',
    'epididymis': 'mào tinh hoàn',
    'seminal vesicle': 'túi tinh',
    'testis': 'tinh hoàn',
    'prostate': 'tuyến tiền liệt',
    'adrenal gland': 'tuyến thượng thận',
    'lobe of thymus': 'thùy tuyến ức',
    'pituitary gland': 'tuyến yên',
    'spleen': 'lách',
    'eyebrow': 'lông mày',
    'hair of head': 'tóc',
    'lip': 'môi',
    'pubic hair': 'lông mu',
    'skin': 'da',

    # --- Sensory ---
    'anterior chamber of eyeball': 'tiền phòng nhãn cầu',
    'choroid': 'màng mạch',
    'cornea': 'giác mạc',
    'iris': 'mống mắt',
    'lens': 'thể thủy tinh',
    'sclera': 'củng mạc',
    'vitreous body': 'thể pha lê',
    'optic part of retina': 'phần thị giác võng mạc',
    'lacrimal gland': 'tuyến lệ',
    'lacrimal sac': 'túi lệ',
    'lacrimal canaliculus': 'tiểu quản lệ',
    'lacrimal lake': 'hồ lệ',
    'nasolacrimal duct': 'ống lệ - mũi',
    'corona ciliaris': 'vành mi',
    'common tendinous ring': 'vòng gân chung',
    'suspensory ligament of lens': 'dây chằng treo thể thủy tinh',
    'tarsal plate of upper eyelid': 'sụn mi trên',
    'tarsal plate of lower eyelid': 'sụn mi dưới',
    'external ear': 'tai ngoài',
    'check ligament of lateral rectus': 'dây chằng hãm cơ thẳng ngoài',
    'check ligament of medial rectus': 'dây chằng hãm cơ thẳng trong',

    # --- Nervous ---
    'cerebellum': 'tiểu não',
    'corpus callosum': 'thể chai',
    'pons': 'cầu não',
    'medulla oblongata': 'hành não',
    'midbrain': 'trung não',
    'hypothalamus': 'vùng dưới đồi',
    'thalamus': 'đồi thị',
    'hippocampus': 'hồi hải mã',
    'amygdala': 'thể hạnh nhân',
    'optic nerve': 'thần kinh thị giác',
    'optic chiasm': 'giao thoa thị giác',
    'optic tract': 'dải thị giác',
    'third ventricle': 'não thất ba',
    'fourth ventricle': 'não thất tư',
    'lateral ventricle': 'não thất bên',
    'cerebral aqueduct': 'cống não',
    'pineal body': 'tuyến tùng',
    'insula': 'thùy đảo',
    'occipital lobe': 'thùy chẩm',
    'caudate nucleus': 'nhân đuôi',
    'putamen': 'nhân bèo sẫm',
    'globus pallidus': 'nhân cầu nhạt',
    'internal capsule': 'bao trong',
    'precentral gyrus': 'hồi trước trung tâm',
    'postcentral gyrus': 'hồi sau trung tâm',
    'superior frontal gyrus': 'hồi trán trên',
    'middle frontal gyrus': 'hồi trán giữa',
    'inferior frontal gyrus': 'hồi trán dưới',
    'middle temporal gyrus': 'hồi thái dương giữa',
    'inferior temporal gyrus': 'hồi thái dương dưới',
    'anterior part of superior temporal gyrus': 'phần trước hồi thái dương trên',
    'posterior part of superior temporal gyrus': 'phần sau hồi thái dương trên',
    'cingulate gyrus': 'hồi đai',
    'angular gyrus': 'hồi góc',
    'supramarginal gyrus': 'hồi trên viền',
    'parahippocampal gyrus': 'hồi cạnh hải mã',
    'superior parietal lobule': 'tiểu thùy đỉnh trên',
    'orbital gyrus': 'hồi ổ mắt',
    'fornix of forebrain': 'vòm não',
    'commissure of fornix of forebrain': 'mép vòm não',
    'mammillary body': 'thể vú',
    'superior colliculus': 'gò trên',
    'inferior colliculus': 'gò dưới',
    'brachium of superior colliculus': 'cánh tay gò trên',
    'brachium of inferior colliculus': 'cánh tay gò dưới',
    'lateral geniculate body': 'thể gối ngoài',
    'medial geniculate body': 'thể gối trong',
    'anterior commissure': 'mép trước',
    'posterior commissure': 'mép sau',
    'central canal of spinal cord': 'ống trung tâm tủy sống',
    'interventricular foramen': 'lỗ gian não thất',
    'lamina terminalis': 'mảnh tận cùng',
    'tuber cinereum': 'củ xám',
    'interpeduncular fossa': 'hố gian cuống',
    'peduncle of midbrain': 'cuống đại não',
    'tentorium cerebelli': 'lều tiểu não',
    'choroid plexus of cerebral hemisphere': 'đám rối mạch mạc bán cầu đại não',
    'white matter of cerebral hemisphere': 'chất trắng bán cầu đại não',
    'stria terminalis': 'vân tận cùng',
    'stria medullaris of thalamus': 'vân tủy đồi thị',
    'ophthalmic nerve': 'thần kinh mắt',
    'trochlear nerve': 'thần kinh ròng rọc',
    'superior branch of oculomotor nerve': 'nhánh trên thần kinh vận nhãn',
    'inferior branch of oculomotor nerve': 'nhánh dưới thần kinh vận nhãn',
    'ciliary ganglion': 'hạch mi',
    'lacrimal nerve': 'thần kinh lệ',
    'frontal nerve': 'thần kinh trán',
    'nasociliary nerve': 'thần kinh mũi mi',
    'supra-orbital nerve': 'thần kinh trên ổ mắt',
    'supratrochlear nerve': 'thần kinh trên ròng rọc',
    'infratrochlear nerve': 'thần kinh dưới ròng rọc',
    'long ciliary nerve': 'thần kinh mi dài',
    'short ciliary nerve': 'thần kinh mi ngắn',
    'anterior ethmoidal nerve': 'thần kinh sàng trước',
    'posterior ethmoidal nerve': 'thần kinh sàng sau',

    # --- Muscles (single words / fixed names) ---
    'diaphragm': 'cơ hoành',
    'external anal sphincter': 'cơ thắt hậu môn ngoài',
    'external intercostal muscle': 'cơ gian sườn ngoài',
    'internal intercostal muscle': 'cơ gian sườn trong',
    'innermost intercostal muscle': 'cơ gian sườn trong cùng',
    'interosseous membrane of forearm': 'màng gian cốt cẳng tay',
    'interosseous membrane of leg': 'màng gian cốt cẳng chân',
    'linea alba': 'đường trắng',
    'flexor retinaculum of wrist': 'mạc giữ gân gấp cổ tay',
    'tendinous arch of levator ani': 'cung gân cơ nâng hậu môn',
    'pharyngeal raphe': 'đường đan hầu',
    'pterygomandibular raphe': 'đường đan chân bướm - hàm',
    'calcaneal tendon': 'gân gót',
    'iliotibial tract': 'dải chậu - chày',
    'uvular muscle': 'cơ lưỡi gà',
    'set of lumbricals of hand': 'các cơ giun bàn tay',
    'set of dorsal interossei of hand': 'các cơ gian cốt mu tay',
    'set of palmar interossei of hand': 'các cơ gian cốt gan tay',
    'set of levatores costarum breves': 'các cơ nâng sườn ngắn',
    'set of levatores costarum longi': 'các cơ nâng sườn dài',
    'set of interspinales cervicis': 'các cơ gian gai cổ',
    'set of interspinales lumborum': 'các cơ gian gai thắt lưng',
    'set of anterior cervical intertransversarii': 'các cơ gian mỏm ngang cổ trước',
    'set of posterior cervical intertransversarii': 'các cơ gian mỏm ngang cổ sau',
    'lateral lumbar intertransversarius': 'cơ gian mỏm ngang thắt lưng ngoài',
    'medial lumbar intertransversarius': 'cơ gian mỏm ngang thắt lưng trong',

    # --- Heart and great vessels ---
    'ascending aorta': 'động mạch chủ lên',
    'arch of aorta': 'cung động mạch chủ',
    'descending aorta': 'động mạch chủ xuống',
    'descending thoracic aorta': 'động mạch chủ ngực',
    'abdominal aorta': 'động mạch chủ bụng',
    'superior vena cava': 'tĩnh mạch chủ trên',
    'inferior vena cava': 'tĩnh mạch chủ dưới',
    'pulmonary trunk': 'thân động mạch phổi',
    'coronary sinus': 'xoang tĩnh mạch vành',
    'great cardiac vein': 'tĩnh mạch tim lớn',
    'middle cardiac vein': 'tĩnh mạch tim giữa',
    'small cardiac vein': 'tĩnh mạch tim nhỏ',
    'anterior cardiac vein': 'tĩnh mạch tim trước',
    'wall of atrium': 'thành tâm nhĩ',
    'wall of ventricle': 'thành tâm thất',
    'cavity of atrium': 'buồng tâm nhĩ',
    'cavity of ventricle': 'buồng tâm thất',
    'anterior leaflet of mitral valve': 'lá trước van hai lá',
    'posterior leaflet of mitral valve': 'lá sau van hai lá',
    'anterior leaflet of tricuspid valve': 'lá trước van ba lá',
    'posterior leaflet of tricuspid valve': 'lá sau van ba lá',
    'septal leaflet of tricuspid valve': 'lá vách van ba lá',
    'anterior cusp of aortic valve': 'lá van trước van động mạch chủ',
    'posterior cusp of aortic valve': 'lá van sau van động mạch chủ',
    'anterior cusp of pulmonary valve': 'lá van trước van động mạch phổi',
    'posterior cusp of pulmonary valve': 'lá van sau van động mạch phổi',
    'left posterior cusp of aortic valve': 'lá van sau trái van động mạch chủ',
    'right posterior cusp of aortic valve': 'lá van sau phải van động mạch chủ',
    'left anterior cusp of pulmonary valve': 'lá van trước trái van động mạch phổi',
    'right anterior cusp of pulmonary valve': 'lá van trước phải van động mạch phổi',
    'anterior papillary muscle of ventricle': 'cơ nhú trước tâm thất',
    'posterior papillary muscle of ventricle': 'cơ nhú sau tâm thất',
    'septal papillary muscle of ventricle': 'cơ nhú vách tâm thất',
    'lateral papillary muscle of ventricle': 'cơ nhú bên tâm thất',
    'trunk of coronary artery': 'thân động mạch vành',
    'circumflex branch of coronary artery': 'nhánh mũ động mạch vành',
    'marginal branch of coronary artery': 'nhánh bờ động mạch vành',
    'posterior interventricular branch of coronary artery': 'nhánh gian thất sau động mạch vành',
    'trunk of anterior interventricular branch of coronary artery':
        'thân nhánh gian thất trước động mạch vành',
    'anterior interventricular vein': 'tĩnh mạch gian thất trước',
    'brachiocephalic artery': 'thân động mạch cánh tay đầu',
    'celiac trunk': 'thân tạng',
    'celiac artery': 'động mạch thân tạng',
    'hepatic artery proper': 'động mạch gan riêng',
    'common hepatic artery': 'động mạch gan chung',
    'hepatic portal vein': 'tĩnh mạch cửa',
    'portal vein': 'tĩnh mạch cửa',
    'trunk of portal vein': 'thân tĩnh mạch cửa',
    'thyrocervical trunk': 'thân giáp cổ',
    'costocervical trunk': 'thân sườn cổ',
    'superficial palmar arterial arch': 'cung động mạch gan tay nông',
    'deep palmar arch': 'cung động mạch gan tay sâu',
    'superficial palmar venous arch': 'cung tĩnh mạch gan tay nông',
    'deep palmar venous arch': 'cung tĩnh mạch gan tay sâu',
    'plantar arch': 'cung động mạch gan chân',
    'plantar venous arch of foot': 'cung tĩnh mạch gan chân',
    'dorsal venous arch of foot': 'cung tĩnh mạch mu chân',
    'dorsal venous network of hand': 'mạng tĩnh mạch mu tay',
    'posterior intercostal arteries': 'các động mạch gian sườn sau',
    'set of anterior intercostal veins': 'các tĩnh mạch gian sườn trước',
    'arteria princeps pollicis': 'động mạch chính ngón cái',
    'arteria radialis indicis': 'động mạch quay ngón trỏ',
    'trunk of renal artery': 'thân động mạch thận',
    'trunk of superior mesenteric artery': 'thân động mạch mạc treo tràng trên',
    'trunk of hepatic artery': 'thân động mạch gan',
    'trunk of gastroduodenal artery': 'thân động mạch vị - tá tràng',
    'trunk of thoraco-acromial artery': 'thân động mạch cùng vai - ngực',
}

# Muscles named "<x>" (side removed). Value is the name without the "cơ" prefix.
MUSCLES = {
    'biceps brachii': 'nhị đầu cánh tay',
    'triceps brachii': 'tam đầu cánh tay',
    'biceps femoris': 'nhị đầu đùi',
    'deltoid': 'delta',
    'pectoralis major': 'ngực lớn',
    'pectoralis minor': 'ngực bé',
    'trapezius': 'thang',
    'gastrocnemius': 'bụng chân',
    'flexor carpi ulnaris': 'gấp cổ tay trụ',
    'flexor carpi radialis': 'gấp cổ tay quay',
    'pronator teres': 'sấp tròn',
    'pronator quadratus': 'sấp vuông',
    'abductor digiti minimi of hand': 'dạng ngón út (bàn tay)',
    'abductor digiti minimi of foot': 'dạng ngón út (bàn chân)',
    'flexor digiti minimi brevis of hand': 'gấp ngón út ngắn (bàn tay)',
    'flexor digiti minimi brevis of foot': 'gấp ngón út ngắn (bàn chân)',
    'opponens digiti minimi of hand': 'đối chiếu ngón út (bàn tay)',
    'opponens digiti minimi of foot': 'đối chiếu ngón út (bàn chân)',
    'flexor hallucis brevis': 'gấp ngón cái ngắn (bàn chân)',
    'flexor hallucis longus': 'gấp ngón cái dài (bàn chân)',
    'adductor hallucis': 'khép ngón cái (bàn chân)',
    'abductor hallucis': 'dạng ngón cái (bàn chân)',
    'extensor hallucis brevis': 'duỗi ngón cái ngắn (bàn chân)',
    'extensor hallucis longus': 'duỗi ngón cái dài (bàn chân)',
    'adductor pollicis': 'khép ngón cái',
    'abductor pollicis brevis': 'dạng ngón cái ngắn',
    'abductor pollicis longus': 'dạng ngón cái dài',
    'extensor pollicis brevis': 'duỗi ngón cái ngắn',
    'extensor pollicis longus': 'duỗi ngón cái dài',
    'flexor pollicis brevis': 'gấp ngón cái ngắn',
    'flexor pollicis longus': 'gấp ngón cái dài',
    'opponens pollicis': 'đối chiếu ngón cái',
    'adductor brevis': 'khép ngắn',
    'adductor longus': 'khép dài',
    'adductor magnus': 'khép lớn',
    'adductor minimus': 'khép bé',
    'anconeus': 'khuỷu',
    'brachialis': 'cánh tay',
    'brachioradialis': 'cánh tay quay',
    'coracobrachialis': 'quạ cánh tay',
    'extensor carpi radialis brevis': 'duỗi cổ tay quay ngắn',
    'extensor carpi radialis longus': 'duỗi cổ tay quay dài',
    'extensor carpi ulnaris': 'duỗi cổ tay trụ',
    'extensor digiti minimi': 'duỗi ngón út',
    'extensor digitorum': 'duỗi các ngón tay',
    'extensor digitorum longus': 'duỗi các ngón chân dài',
    'extensor indicis': 'duỗi ngón trỏ',
    'external oblique': 'chéo bụng ngoài',
    'fibularis brevis': 'mác ngắn',
    'fibularis longus': 'mác dài',
    'fibularis tertius': 'mác ba',
    'flexor accessorius': 'vuông gan chân',
    'flexor digitorum brevis': 'gấp các ngón chân ngắn',
    'flexor digitorum longus': 'gấp các ngón chân dài',
    'flexor digitorum profundus': 'gấp các ngón tay sâu',
    'flexor digitorum superficialis': 'gấp các ngón tay nông',
    'gemellus inferior': 'sinh đôi dưới',
    'gemellus superior': 'sinh đôi trên',
    'genioglossus': 'cằm - lưỡi',
    'geniohyoid': 'cằm - móng',
    'gluteus maximus': 'mông lớn',
    'gluteus medius': 'mông nhỡ',
    'gluteus minimus': 'mông bé',
    'gracilis': 'thon',
    'hyoglossus': 'móng - lưỡi',
    'iliacus': 'chậu',
    'iliococcygeus': 'chậu - cụt',
    'iliocostalis cervicis': 'chậu sườn cổ',
    'iliocostalis lumborum': 'chậu sườn thắt lưng',
    'iliocostalis thoracis': 'chậu sườn ngực',
    'infraspinatus muscle': 'dưới gai',
    'interspinalis thoracis': 'gian gai ngực',
    'inferior oblique': 'chéo dưới (mắt)',
    'superior oblique': 'chéo trên (mắt)',
    'inferior rectus': 'thẳng dưới (mắt)',
    'superior rectus': 'thẳng trên (mắt)',
    'lateral rectus': 'thẳng ngoài (mắt)',
    'medial rectus': 'thẳng trong (mắt)',
    'levator palpebrae superioris': 'nâng mi trên',
    'levator scapulae': 'nâng vai',
    'levator veli palatini': 'nâng màn hầu',
    'tensor veli palatini': 'căng màn hầu',
    'longissimus capitis': 'dài nhất đầu',
    'longissimus cervicis': 'dài nhất cổ',
    'longissimus thoracis': 'dài nhất ngực',
    'longus capitis': 'dài đầu',
    'longus colli': 'dài cổ',
    'cervical rotator': 'xoay cổ',
    'thoracic rotator': 'xoay ngực',
    'lumbar rotator': 'xoay thắt lưng',
    'coccygeus': 'cụt',
    'digastric': 'hai bụng',
    'mylohyoid': 'hàm - móng',
    'obliquus capitis inferior': 'chéo đầu dưới',
    'obliquus capitis superior': 'chéo đầu trên',
    'obturator externus': 'bịt ngoài',
    'obturator internus': 'bịt trong',
    'omohyoid': 'vai - móng',
    'palatopharyngeus': 'khẩu cái - hầu',
    'palmaris longus': 'gan tay dài',
    'pectineus': 'lược',
    'piriformis': 'hình lê',
    'plantaris': 'gan chân',
    'platysma': 'bám da cổ',
    'popliteus': 'khoeo',
    'psoas major': 'thắt lưng lớn',
    'pubococcygeus': 'mu - cụt',
    'puborectalis': 'mu - trực tràng',
    'quadratus femoris': 'vuông đùi',
    'rectus capitis anterior': 'thẳng đầu trước',
    'rectus capitis lateralis': 'thẳng đầu ngoài',
    'rectus capitis posterior major': 'thẳng đầu sau lớn',
    'rectus capitis posterior minor': 'thẳng đầu sau bé',
    'rectus femoris': 'thẳng đùi',
    'rhomboid major': 'trám lớn',
    'rhomboid minor': 'trám bé',
    'salpingopharyngeus': 'vòi - hầu',
    'sartorius': 'may',
    'scalenus anterior': 'bậc thang trước',
    'scalenus medius': 'bậc thang giữa',
    'scalenus posterior': 'bậc thang sau',
    'semimembranosus': 'bán màng',
    'semitendinosus': 'bán gân',
    'semispinalis capitis': 'bán gai đầu',
    'semispinalis cervicis': 'bán gai cổ',
    'semispinalis thoracis': 'bán gai ngực',
    'serratus anterior': 'răng trước',
    'serratus posterior inferior': 'răng sau dưới',
    'serratus posterior superior': 'răng sau trên',
    'soleus': 'dép',
    'spinalis': 'gai',
    'spinalis thoracis': 'gai ngực',
    'splenius capitis': 'gối đầu',
    'splenius cervicis': 'gối cổ',
    'sternocleidomastoid': 'ức - đòn - chũm',
    'sternohyoid': 'ức - móng',
    'sternothyroid': 'ức - giáp',
    'stylohyoid': 'trâm - móng',
    'stylopharyngeus': 'trâm - hầu',
    'subclavius': 'dưới đòn',
    'subscapularis': 'dưới vai',
    'supinator': 'ngửa',
    'supraspinatus': 'trên gai',
    'tensor fasciae latae': 'căng mạc đùi',
    'teres major': 'tròn lớn',
    'teres minor': 'tròn bé',
    'thyrohyoid': 'giáp - móng',
    'tibialis anterior': 'chày trước',
    'tibialis posterior': 'chày sau',
    'transversus thoracis': 'ngang ngực',
    'vastus intermedius': 'rộng giữa',
    'vastus lateralis': 'rộng ngoài',
    'vastus medialis': 'rộng trong',
    'vocalis': 'thanh âm',
    'thyro-arytenoid': 'giáp - phễu',
    'posterior crico-arytenoid': 'nhẫn - phễu sau',
    'lateral crico-arytenoid': 'nhẫn - phễu bên',
    'oblique arytenoid': 'phễu chéo',
    'transverse arytenoid': 'phễu ngang',
    'aryepiglotticus': 'phễu - nắp thanh môn',
    'cricothyroid': 'nhẫn - giáp',
    'superior pharyngeal constrictor': 'khít hầu trên',
    'middle pharyngeal constrictor': 'khít hầu giữa',
    'inferior pharyngeal constrictor': 'khít hầu dưới',
}

# Sub-parts of muscles: "<part> of <muscle>".
MUSCLE_PARTS = {
    'long head': 'đầu dài', 'short head': 'đầu ngắn', 'lateral head': 'đầu ngoài',
    'medial head': 'đầu trong', 'oblique head': 'đầu chéo', 'transverse head': 'đầu ngang',
    'humeral head': 'đầu cánh tay', 'ulnar head': 'đầu trụ', 'superficial head': 'đầu nông',
    'acromial part': 'phần cùng vai', 'clavicular part': 'phần đòn', 'spinal part': 'phần gai',
    'sternocostal part': 'phần ức - sườn', 'abdominal part': 'phần bụng',
    'descending part': 'phần xuống', 'ascending part': 'phần lên', 'transverse part': 'phần ngang',
    'straight part': 'phần thẳng', 'oblique part': 'phần chéo',
    'superior oblique part': 'phần chéo trên', 'inferior oblique part': 'phần chéo dưới',
    'vertical intermediate part': 'phần thẳng giữa', 'tendon': 'gân',
}

# Modifiers of "<modifier> artery" / "<modifier> vein" (side removed).
VESSELS = {
    'common carotid': 'cảnh chung', 'internal carotid': 'cảnh trong',
    'internal jugular': 'cảnh trong', 'vertebral': 'đốt sống', 'basilar': 'nền',
    'subclavian': 'dưới đòn', 'axillary': 'nách', 'brachial': 'cánh tay',
    'deep brachial': 'cánh tay sâu', 'radial': 'quay', 'ulnar': 'trụ',
    'brachiocephalic': 'cánh tay đầu', 'femoral': 'đùi', 'deep femoral': 'đùi sâu',
    'popliteal': 'khoeo', 'anterior tibial': 'chày trước', 'posterior tibial': 'chày sau',
    'fibular': 'mác', 'dorsalis pedis': 'mu chân',
    'common iliac': 'chậu chung', 'external iliac': 'chậu ngoài', 'internal iliac': 'chậu trong',
    'renal': 'thận', 'splenic': 'lách', 'hepatic': 'gan', 'middle hepatic': 'gan giữa',
    'superior mesenteric': 'mạc treo tràng trên', 'inferior mesenteric': 'mạc treo tràng dưới',
    'cephalic': 'đầu', 'basilic': 'nền', 'median cubital': 'giữa khuỷu',
    'median antebrachial': 'giữa cẳng tay',
    'great saphenous': 'hiển lớn', 'small saphenous': 'hiển bé',
    'azygos': 'đơn', 'hemiazygos': 'bán đơn', 'accessory hemiazygos': 'bán đơn phụ',
    'gastric': 'vị', 'gastro-epiploic': 'vị - mạc nối', 'gastroepiploic': 'vị - mạc nối',
    'ileocolic': 'hồi - đại tràng', 'middle colic': 'đại tràng giữa', 'colic': 'đại tràng',
    'sigmoid': 'sigma', 'superior rectal': 'trực tràng trên', 'appendicular': 'ruột thừa',
    'ileal': 'hồi tràng', 'testicular': 'tinh hoàn', 'suprarenal': 'thượng thận',
    'middle suprarenal': 'thượng thận giữa', 'inferior suprarenal': 'thượng thận dưới',
    'inferior phrenic': 'hoành dưới', 'superior phrenic': 'hoành trên',
    'internal thoracic': 'ngực trong', 'lateral thoracic': 'ngực ngoài',
    'thoracodorsal': 'ngực - lưng', 'subscapular': 'dưới vai', 'suprascapular': 'trên vai',
    'circumflex scapular': 'mũ vai', 'anterior circumflex humeral': 'mũ cánh tay trước',
    'posterior circumflex humeral': 'mũ cánh tay sau',
    'lateral circumflex femoral': 'mũ đùi ngoài', 'medial circumflex femoral': 'mũ đùi trong',
    'transverse cervical': 'cổ ngang', 'inferior thyroid': 'giáp dưới',
    'superior epigastric': 'thượng vị trên', 'inferior epigastric': 'thượng vị dưới',
    'superficial epigastric': 'thượng vị nông', 'musculophrenic': 'cơ hoành',
    'anterior cerebral': 'não trước', 'middle cerebral': 'não giữa', 'posterior cerebral': 'não sau',
    'anterior communicating': 'thông trước', 'posterior communicating': 'thông sau',
    'superior cerebellar': 'tiểu não trên', 'anterior inferior cerebellar': 'tiểu não trước dưới',
    'posterior inferior cerebellar': 'tiểu não sau dưới', 'ophthalmic': 'mắt',
    'anterior spinal': 'tủy sống trước', 'lumbar': 'thắt lưng', 'ascending lumbar': 'thắt lưng lên',
    'subcostal': 'dưới sườn', 'deep plantar': 'gan chân sâu', 'medial plantar': 'gan chân trong',
    'lateral plantar': 'gan chân ngoài', 'arcuate': 'cung', 'radial recurrent': 'quặt ngược quay',
    'anterior ulnar recurrent': 'quặt ngược trụ trước',
    'posterior ulnar recurrent': 'quặt ngược trụ sau',
    'anterior tibial recurrent': 'quặt ngược chày trước',
    'common interosseous': 'gian cốt chung', 'anterior interosseous': 'gian cốt trước',
    'recurrent interosseous': 'gian cốt quặt ngược',
    'superior ulnar collateral': 'bên trụ trên', 'inferior ulnar collateral': 'bên trụ dưới',
    'descending genicular': 'xuống gối', 'lateral superior genicular': 'gối trên ngoài',
    'medial superior genicular': 'gối trên trong', 'inferior lateral genicular': 'gối dưới ngoài',
    'inferior medial genicular': 'gối dưới trong', 'middle genicular': 'gối giữa',
    'genicular': 'gối', 'superior gluteal': 'mông trên', 'inferior gluteal': 'mông dưới',
    'internal pudendal': 'thẹn trong', 'obturator': 'bịt', 'iliolumbar': 'chậu - thắt lưng',
    'lateral sacral': 'cùng bên', 'median sacral': 'cùng giữa', 'dorsal scapular': 'vai sau',
    'deep cervical': 'cổ sâu', 'superficial cervical': 'cổ nông',
    'superior intercostal': 'gian sườn trên', 'first posterior intercostal': 'gian sườn sau thứ nhất',
    'second posterior intercostal': 'gian sườn sau thứ hai',
    'pulmonary': 'phổi', 'superior pulmonary': 'phổi trên', 'inferior pulmonary': 'phổi dưới',
    'bronchial': 'phế quản', 'esophageal': 'thực quản',
    'coronary': 'vành', 'thoraco-acromial': 'cùng vai - ngực',
    'anterior choroidal': 'mạch mạc trước', 'pericallosal': 'quanh thể chai',
    'callosomarginal': 'thể chai - viền', 'medial brachial': 'cánh tay trong',
    'dorsal metacarpal': 'mu đốt bàn tay', 'palmar metacarpal': 'gan đốt bàn tay',
    'plantar metatarsal': 'gan đốt bàn chân', 'ileal': 'hồi tràng',
    'inferior mesenteric': 'mạc treo tràng dưới', 'pancreaticoduodenal': 'tụy - tá tràng',
    'inferior pancreaticoduodenal': 'tụy - tá tràng dưới',
    'superior lingular': 'phân thùy lưỡi trên', 'inferior lingular': 'phân thùy lưỡi dưới',
    'anterior superior pancreaticoduodenal': 'tụy - tá tràng trên trước',
    'posterior superior pancreaticoduodenal': 'tụy - tá tràng trên sau',
    'anterior inferior pancreaticoduodenal': 'tụy - tá tràng dưới trước',
    'posterior inferior pancreaticoduodenal': 'tụy - tá tràng dưới sau',
    'anterior cecal': 'manh tràng trước', 'posterior cecal': 'manh tràng sau',
    'first common palmar digital': 'gan ngón tay chung thứ nhất',
    'second common palmar digital': 'gan ngón tay chung thứ hai',
    'third common palmar digital': 'gan ngón tay chung thứ ba',
    'fourth common palmar digital': 'gan ngón tay chung thứ tư',
    'common palmar digital': 'gan ngón tay chung', 'lateral tarsal': 'cổ chân ngoài',
    'prefrontal': 'trước trán', 'anterior parietal': 'đỉnh trước', 'posterior parietal': 'đỉnh sau',
    'anterior temporal': 'thái dương trước', 'polar temporal': 'cực thái dương',
    'lateral occipital': 'chẩm ngoài', 'medial occipital': 'chẩm trong',
    'lateral frontobasal': 'trán nền ngoài', 'medial frontobasal': 'trán nền trong',
    'thalamogeniculate': 'đồi thị - gối', 'thalamoperforating': 'xuyên đồi thị',
    'posterior medial choroidal': 'mạch mạc sau trong', 'conus': 'nón', 'pontine': 'cầu não',
    'upper lobar': 'thùy trên', 'dorsal metacarpal': 'mu đốt bàn tay',
}

# "<modifier> branch of <vessel>".
BRANCHES = {
    'acromial': 'cùng vai', 'deltoid': 'delta', 'pectoral': 'ngực', 'descending': 'xuống',
    'ascending': 'lên', 'dorsal carpal': 'mu cổ tay', 'radial collateral': 'bên quay',
    'middle collateral': 'bên giữa', 'lateral': 'ngoài', 'medial': 'trong',
    'superior segmental': 'phân thùy trên', 'inferior segmental': 'phân thùy dưới',
    'posterior segmental': 'phân thùy sau', 'middle temporal': 'thái dương giữa',
    'posterior temporal': 'thái dương sau', 'anterior temporal': 'thái dương trước',
    'hypothalamic': 'vùng dưới đồi', 'paracentral': 'cạnh trung tâm', 'caudate lobe': 'thùy đuôi',
}

# Lung segments (bronchial trees and segmental vessels).
SEGMENTS = {
    'apical': 'đỉnh', 'posterior': 'sau', 'anterior': 'trước', 'superior': 'trên',
    'lateral basal': 'đáy bên', 'medial basal': 'đáy trong', 'anterior basal': 'đáy trước',
    'posterior basal': 'đáy sau', 'lateral': 'bên', 'medial': 'giữa',
    'superior lingular': 'lưỡi trên', 'inferior lingular': 'lưỡi dưới',
}

FINGERS = {
    'thumb': 'ngón cái', 'index finger': 'ngón trỏ', 'middle finger': 'ngón giữa',
    'ring finger': 'ngón nhẫn', 'little finger': 'ngón út',
    'big toe': 'ngón chân cái', 'second toe': 'ngón chân thứ hai', 'third toe': 'ngón chân thứ ba',
    'fourth toe': 'ngón chân thứ tư', 'little toe': 'ngón chân út',
}
PHALANX = {'distal': 'đốt xa', 'middle': 'đốt giữa', 'proximal': 'đốt gần'}

REGION = {'cervical': 'cổ', 'thoracic': 'ngực', 'lumbar': 'thắt lưng'}

TOOTH = {
    'central incisor': 'răng cửa giữa', 'lateral incisor': 'răng cửa bên', 'canine': 'răng nanh',
    'first premolar': 'răng hàm nhỏ thứ nhất', 'second premolar': 'răng hàm nhỏ thứ hai',
    'first molar': 'răng hàm lớn thứ nhất', 'second molar': 'răng hàm lớn thứ hai',
    'third molar': 'răng hàm lớn thứ ba',
}
JAW = {'upper': 'hàm trên', 'lower': 'hàm dưới'}

HEPATIC_SEGMENTS = {'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'}


def core(name):
    """Vietnamese for a side-less English name (lower case), or None."""
    n = name.lower().strip()
    if n in TERMS:
        return TERMS[n]
    if n in MUSCLES:
        return 'cơ ' + MUSCLES[n]

    m = re.fullmatch(r'(distal|middle|proximal) phalanx of (.+)', n)
    if m and m.group(2) in FINGERS:
        return f'{PHALANX[m.group(1)]} {FINGERS[m.group(2)]}'

    m = re.fullmatch(rf'({ORD_RE}) (metacarpal|metatarsal) bone', n)
    if m:
        where = 'bàn tay' if m.group(2) == 'metacarpal' else 'bàn chân'
        return f'xương đốt {where} {ORDINAL_WORD[ORDINAL[m.group(1)]]}'

    m = re.fullmatch(rf'({ORD_RE}) (cervical|thoracic|lumbar) vertebra', n)
    if m:
        return f'đốt sống {REGION[m.group(2)]} {ORDINAL[m.group(1)]}'

    m = re.fullmatch(r'intervertebral disk of (.+)', n)
    if m:
        target = core(m.group(1))
        if target is None:
            return None
        target = re.sub(r'^đốt sống ', '', target)
        return f'đĩa gian đốt sống {target}'

    m = re.fullmatch(rf'({ORD_RE}) (rib|costal cartilage)', n)
    if m:
        head = 'xương sườn' if m.group(2) == 'rib' else 'sụn sườn'
        return f'{head} {ORDINAL[m.group(1)]}'

    m = re.fullmatch(r'(upper|lower) (.+?) secondary (\w+) tooth', n)
    if m and f'{m.group(2)} {m.group(3)}' in TOOTH:
        return f'{TOOTH[m.group(2) + " " + m.group(3)]} {JAW[m.group(1)]}'
    m = re.fullmatch(r'(upper|lower) secondary canine tooth', n)
    if m:
        return f'răng nanh {JAW[m.group(1)]}'

    m = re.fullmatch(r'hepatovenous segment ([ivx]+)', n)
    if m and m.group(1).upper() in HEPATIC_SEGMENTS:
        return f'phân thùy gan {m.group(1).upper()}'

    m = re.fullmatch(r'(distal|middle|proximal) part of (ileum|jejunum)', n)
    if m:
        part = {'distal': 'đoạn xa', 'middle': 'đoạn giữa', 'proximal': 'đoạn gần'}[m.group(1)]
        return f'{part} {TERMS[m.group(2)]}'

    m = re.fullmatch(r'(.+) segmental bronchial tree', n)
    if m and m.group(1) in SEGMENTS:
        return f'phế quản phân thùy {SEGMENTS[m.group(1)]}'
    m = re.fullmatch(r'(superior|inferior) lingular bronchial tree', n)
    if m:
        return f'phế quản phân thùy {SEGMENTS[m.group(1) + " lingular"]}'
    m = re.fullmatch(r'(.+) segmental (artery|vein)', n)
    if m and m.group(1) in SEGMENTS:
        kind = 'động mạch' if m.group(2) == 'artery' else 'tĩnh mạch'
        return f'{kind} phân thùy {SEGMENTS[m.group(1)]}'

    m = re.fullmatch(r'(first|second|third|fourth) (lumbrical|plantar interosseous) of foot', n)
    if m:
        kind = 'cơ giun' if m.group(2) == 'lumbrical' else 'cơ gian cốt gan chân'
        return f'{kind} {ORDINAL_WORD[ORDINAL[m.group(1)]]} bàn chân'

    m = re.fullmatch(r'(.+?) of (.+)', n)
    if m and m.group(1) in MUSCLE_PARTS:
        muscle = m.group(2)
        if muscle in MUSCLES:
            return f'{MUSCLE_PARTS[m.group(1)]} cơ {MUSCLES[muscle]}'

    m = re.fullmatch(r'(.+) branch of (.+)', n)
    if m and m.group(1) in BRANCHES:
        inner = core(m.group(2))
        if inner and inner.startswith(('động mạch', 'tĩnh mạch')):
            return f'nhánh {BRANCHES[m.group(1)]} {inner}'
    m = re.fullmatch(r'(anterior|posterior) division of renal artery', n)
    if m:
        return f'ngành {"trước" if m.group(1) == "anterior" else "sau"} động mạch thận'
    m = re.fullmatch(r'(insular|sphenoid) part of middle cerebral artery', n)
    if m:
        return f'phần {"đảo" if m.group(1) == "insular" else "bướm"} động mạch não giữa'
    m = re.fullmatch(r'proper palmar digital vein of (.+ finger)', n)
    if m and m.group(1) in FINGERS:
        return f'tĩnh mạch gan ngón tay riêng {FINGERS[m.group(1)]}'
    m = re.fullmatch(r'(deep |superficial )?dorsal (artery|vein) of penis', n)
    if m:
        kind = 'động mạch' if m.group(2) == 'artery' else 'tĩnh mạch'
        depth = {'deep ': ' sâu', 'superficial ': ' nông', None: ''}[m.group(1)]
        return f'{kind} mu{depth} dương vật'
    if n == 'marginal artery of colon':
        return 'động mạch bờ đại tràng'

    m = re.fullmatch(r'(.+) (artery|vein)', n)
    if m and m.group(1) in VESSELS:
        kind = 'động mạch' if m.group(2) == 'artery' else 'tĩnh mạch'
        return f'{kind} {VESSELS[m.group(1)]}'

    m = re.fullmatch(r'trunk of (.+)', n)
    if m:
        inner = core(m.group(1))
        if inner and not inner.startswith('thân'):
            return f'thân {inner}'

    return None


def translate(name):
    """Vietnamese for a full English part name, or None when unsure."""
    full = TERMS.get(name.lower())
    if full is not None:
        return _cap(full)
    sides = re.findall(r'\b(left|right)\b', name, flags=re.IGNORECASE)
    if len(sides) > 1:
        return None
    side = sides[0].lower() if sides else None
    stripped = re.sub(r'\b(left|right) ', '', name, count=1, flags=re.IGNORECASE)
    vi = core(stripped)
    if vi is None:
        return None
    if side:
        vi = f'{vi} {SIDE[side]}'
    return _cap(vi)


def _cap(text):
    return text[:1].upper() + text[1:]


def main():
    with open(PARTS, encoding='utf-8') as f:
        parts = json.load(f)
    out = {}
    total = collections.Counter()
    done = collections.Counter()
    for part in parts:
        total[part['system']] += 1
        vi = translate(part['name'])
        if vi:
            out[part['id']] = vi
            done[part['system']] += 1
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(dict(sorted(out.items())), f, ensure_ascii=False, indent=0, sort_keys=True)
        f.write('\n')
    print(f'{"system":<16}{"vi":>6}{"total":>7}')
    for system, count in total.most_common():
        print(f'{system:<16}{done[system]:>6}{count:>7}')
    print(f'{"all":<16}{sum(done.values()):>6}{sum(total.values()):>7}')
    if '-v' in sys.argv:
        for part in parts:
            if part['id'] not in out:
                print('  untranslated:', part['system'], '|', part['name'])


if __name__ == '__main__':
    main()
