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


# ---------------------------------------------------------------------------
# Structures added from Z-Anatomy (part ids "ZA_…"): joints and cartilages,
# lymph nodes, nerves, vessels of the head and limbs, bursae, tendon sheaths…
# ---------------------------------------------------------------------------
ZA_TERMS = {
    # --- Joints: cartilages, discs, capsules, ligaments ---
    'lateral meniscus': 'sụn chêm ngoài',
    'medial meniscus': 'sụn chêm trong',
    'acetabular labrum': 'sụn viền ổ cối',
    'glenoid labrum': 'sụn viền ổ chảo',
    'interpubic disc': 'đĩa gian mu',
    'pubic symphysis': 'khớp mu',
    'sacrococcygeal symphysis': 'khớp cùng - cụt',
    'infrapatellar fat pad': 'thể mỡ dưới bánh chè',
    'zona orbicularis': 'đới vòng',
    'costal cartilage of eighth rib': 'sụn sườn 8',
    'costal cartilage of ninth rib': 'sụn sườn 9',
    'costal cartilage of tenth rib': 'sụn sườn 10',
    'articular disc of acromioclavicular joint': 'đĩa khớp cùng vai - đòn',
    'articular disc of distal radio-ulnar joint': 'đĩa khớp quay - trụ xa',
    'articular disc of sternoclavicular joint': 'đĩa khớp ức - đòn',
    'articular disc of temporomandibular joint': 'đĩa khớp thái dương - hàm dưới',
    'articular capsule of acromioclavicular joint': 'bao khớp cùng vai - đòn',
    'articular capsule of elbow joint': 'bao khớp khuỷu',
    'articular capsule of glenohumeral joint': 'bao khớp vai',
    'articular capsule of hip joint': 'bao khớp hông',
    'articular capsule of interphalangeal joint of great toe': 'bao khớp gian đốt ngón chân cái',
    'articular capsule of knee joint': 'bao khớp gối',
    'articular capsule of radiocarpal joint': 'bao khớp quay - cổ tay',
    'articular capsule of sternoclavicular joint': 'bao khớp ức - đòn',
    'articular capsule of superior tibiofibular joint': 'bao khớp chày - mác trên',
    'articular capsule of temporomandibular joint': 'bao khớp thái dương - hàm dưới',
    'articular capsules of distal interphalangeal joints': 'các bao khớp gian đốt xa ngón tay',
    'articular capsules of proximal interphalangeal joints': 'các bao khớp gian đốt gần ngón tay',
    'articular capsules of distal interphalangeal joints of foot': 'các bao khớp gian đốt xa ngón chân',
    'articular capsules of proximal interphalangeal joints of foot': 'các bao khớp gian đốt gần ngón chân',
    'articular capsules of metacarpophalangeal joints': 'các bao khớp đốt bàn - ngón tay',
    'articular capsules of metatarsophalangeal joints': 'các bao khớp đốt bàn - ngón chân',
    'external intercostal membrane': 'màng gian sườn ngoài',
    'internal intercostal membrane': 'màng gian sườn trong',
    'obturator membrane': 'màng bịt',
    'anterior cruciate ligament': 'dây chằng chéo trước',
    'posterior cruciate ligament': 'dây chằng chéo sau',
    'anterior longitudinal ligament': 'dây chằng dọc trước',
    'posterior longitudinal ligament': 'dây chằng dọc sau',
    'ligamenta flava': 'các dây chằng vàng',
    'interspinous ligaments': 'các dây chằng gian gai',
    'supraspinous ligament': 'dây chằng trên gai',
    'intertransverse ligaments': 'các dây chằng gian mỏm ngang',
    'nuchal ligament': 'dây chằng gáy',
    'intercornual ligament': 'dây chằng gian sừng',
    'iliolumbar ligament': 'dây chằng chậu - thắt lưng',
    'anterior sacro-iliac ligament': 'dây chằng cùng - chậu trước',
    'posterior sacro-iliac ligament': 'dây chằng cùng - chậu sau',
    'interosseous sacro-iliac ligament': 'dây chằng cùng - chậu gian cốt',
    'sacrospinous ligament': 'dây chằng cùng - gai',
    'sacrotuberous ligament': 'dây chằng cùng - ụ ngồi',
    'superior pubic ligament': 'dây chằng mu trên',
    'inferior pubic ligament': 'dây chằng mu dưới',
    'costotransverse ligament': 'dây chằng sườn - mỏm ngang',
    'radiate ligament of head of rib': 'dây chằng tia chỏm sườn',
    'intra-articular ligament of head of rib': 'dây chằng trong khớp chỏm sườn',
    'anterior sternoclavicular ligament': 'dây chằng ức - đòn trước',
    'posterior sternoclavicular ligament': 'dây chằng ức - đòn sau',
    'interclavicular ligament': 'dây chằng gian đòn',
    'acromioclavicular ligament': 'dây chằng cùng vai - đòn',
    'conoid ligament': 'dây chằng nón',
    'trapezoid ligament': 'dây chằng thang',
    'coracohumeral ligament': 'dây chằng quạ - cánh tay',
    'superior glenohumeral ligament': 'dây chằng ổ chảo - cánh tay trên',
    'middle glenohumeral ligament': 'dây chằng ổ chảo - cánh tay giữa',
    'inferior glenohumeral ligament': 'dây chằng ổ chảo - cánh tay dưới',
    'transverse humeral ligament': 'dây chằng ngang cánh tay',
    'annular ligament of radius': 'dây chằng vòng quay',
    'radial collateral ligament': 'dây chằng bên quay',
    'ulnar collateral ligament': 'dây chằng bên trụ',
    'radial collateral ligament of wrist joint': 'dây chằng bên quay cổ tay',
    'ulnar collateral ligament of wrist joint': 'dây chằng bên trụ cổ tay',
    'palmar radio-ulnar ligament': 'dây chằng quay - trụ gan tay',
    'dorsal radiocarpal ligament': 'dây chằng quay - cổ tay mu tay',
    'radioscaphocapitate ligament': 'dây chằng quay - thuyền - cả',
    'dorsal ulnocarpal ligament': 'dây chằng trụ - cổ tay mu tay',
    'ulnocapitate ligament': 'dây chằng trụ - cả',
    'ulnolunate ligament': 'dây chằng trụ - nguyệt',
    'ulnotriquetral ligament': 'dây chằng trụ - tháp',
    'radiate carpal ligament': 'dây chằng tia cổ tay',
    'dorsal intercarpal ligaments': 'các dây chằng gian cổ tay mu tay',
    'dorsal scaphotriquetral ligament': 'dây chằng thuyền - tháp mu tay',
    'palmar scaphotriquetral ligament': 'dây chằng thuyền - tháp gan tay',
    'scaphotrapeziotrapezoidal ligament': 'dây chằng thuyền - thang - thê',
    'triquetrocapitate ligament': 'dây chằng tháp - cả',
    'pisotriquetral ligament': 'dây chằng đậu - tháp',
    'dorsal carpometacarpal ligaments': 'các dây chằng cổ tay - đốt bàn tay mu tay',
    'palmar carpometacarpal ligaments': 'các dây chằng cổ tay - đốt bàn tay gan tay',
    'dorsal metacarpal ligaments': 'các dây chằng đốt bàn tay mu tay',
    'palmar metacarpal ligaments': 'các dây chằng đốt bàn tay gan tay',
    'interosseous metacarpal ligaments': 'các dây chằng gian cốt đốt bàn tay',
    'collateral metacarpophalangeal ligaments': 'các dây chằng bên đốt bàn - ngón tay',
    'deep transverse metacarpal ligament': 'dây chằng ngang sâu đốt bàn tay',
    'collateral interphalangeal ligaments of hand': 'các dây chằng bên gian đốt ngón tay',
    'palmar interphalangeal ligaments': 'các dây chằng gan tay gian đốt ngón tay',
    'ligament of head of femur': 'dây chằng chỏm đùi',
    'transverse acetabular ligament': 'dây chằng ngang ổ cối',
    'descending part of iliofemoral ligament': 'phần xuống dây chằng chậu - đùi',
    'transverse part of iliofemoral ligament': 'phần ngang dây chằng chậu - đùi',
    'pubofemoral ligament': 'dây chằng mu - đùi',
    'ischiofemoral ligament': 'dây chằng ngồi - đùi',
    'superficial part of tibial collateral ligament': 'phần nông dây chằng bên chày',
    'deep part of tibial collateral ligament': 'phần sâu dây chằng bên chày',
    'fibular collateral ligament': 'dây chằng bên mác',
    'transverse ligament of knee': 'dây chằng ngang gối',
    'meniscopatellar ligament': 'dây chằng sụn chêm - bánh chè',
    'anterior meniscotibial ligament of lateral meniscus': 'dây chằng sụn chêm - chày trước của sụn chêm ngoài',
    'anterior meniscotibial ligament of medial meniscus': 'dây chằng sụn chêm - chày trước của sụn chêm trong',
    'posterior meniscotibial ligament of lateral meniscus': 'dây chằng sụn chêm - chày sau của sụn chêm ngoài',
    'posterior meniscotibial ligament of medial meniscus': 'dây chằng sụn chêm - chày sau của sụn chêm trong',
    'oblique popliteal ligament': 'dây chằng khoeo chéo',
    'arcuate popliteal ligament': 'dây chằng khoeo cung',
    'popliteofibular ligament': 'dây chằng khoeo - mác',
    'anterior ligament of fibular head': 'dây chằng chỏm mác trước',
    'posterior ligament of fibular head': 'dây chằng chỏm mác sau',
    'anterior tibiofibular ligament': 'dây chằng chày - mác trước',
    'posterior tibiofibular ligament': 'dây chằng chày - mác sau',
    'transverse tibiofibular ligament': 'dây chằng chày - mác ngang',
    'anterior talofibular ligament': 'dây chằng sên - mác trước',
    'posterior talofibular ligament': 'dây chằng sên - mác sau',
    'calcaneofibular ligament': 'dây chằng gót - mác',
    'posterior tibiotalar ligament': 'dây chằng chày - sên sau',
    'tibiocalcaneal ligament': 'dây chằng chày - gót',
    'tibionavicular ligament': 'dây chằng chày - ghe',
    'anterior talocalcaneal ligament': 'dây chằng sên - gót trước',
    'posterior talocalcaneal ligament': 'dây chằng sên - gót sau',
    'lateral talocalcaneal ligament': 'dây chằng sên - gót ngoài',
    'medial talocalcaneal ligament': 'dây chằng sên - gót trong',
    'talocalcaneal interosseous ligament': 'dây chằng gian cốt sên - gót',
    'talonavicular ligament': 'dây chằng sên - ghe',
    'calcaneocuboid ligament': 'dây chằng gót - hộp',
    'calcaneonavicular ligament': 'dây chằng gót - ghe',
    'plantar calcaneocuboid ligament': 'dây chằng gót - hộp gan chân',
    'plantar calcaneonavicular ligament': 'dây chằng gót - ghe gan chân',
    'cuneocuboid interosseous ligament': 'dây chằng gian cốt chêm - hộp',
    'plantar cuneocuboid ligament': 'dây chằng chêm - hộp gan chân',
    'dorsal cuneonavicular ligaments': 'các dây chằng chêm - ghe mu chân',
    'plantar cuneonavicular ligaments': 'các dây chằng chêm - ghe gan chân',
    'dorsal intercuneiform ligaments': 'các dây chằng gian chêm mu chân',
    'plantar intercuneiform ligaments': 'các dây chằng gian chêm gan chân',
    'intercuneiform interosseous ligaments': 'các dây chằng gian cốt gian chêm',
    'cuneometatarsal interosseous ligaments': 'các dây chằng gian cốt chêm - đốt bàn chân',
    'dorsal tarsometatarsal ligaments': 'các dây chằng cổ chân - đốt bàn chân mu chân',
    'plantar tarsometatarsal ligaments': 'các dây chằng cổ chân - đốt bàn chân gan chân',
    'dorsal metatarsal ligaments': 'các dây chằng đốt bàn chân mu chân',
    'plantar metatarsal ligaments': 'các dây chằng đốt bàn chân gan chân',
    'metatarsal interosseous ligaments': 'các dây chằng gian cốt đốt bàn chân',
    'intersesamoid ligament': 'dây chằng gian xương vừng',
    'collateral metatarsophalangeal ligaments': 'các dây chằng bên đốt bàn - ngón chân',
    'plantar metatarsophalangeal ligaments': 'các dây chằng gan chân đốt bàn - ngón chân',
    'deep transverse metatarsal ligament': 'dây chằng ngang sâu đốt bàn chân',
    'collateral interphalangeal ligaments of foot': 'các dây chằng bên gian đốt ngón chân',
    'plantar interphalangeal ligaments': 'các dây chằng gan chân gian đốt ngón chân',
    'lateral temporomandibular ligament': 'dây chằng thái dương - hàm dưới ngoài',
    'sphenomandibular ligament': 'dây chằng bướm - hàm dưới',
    'stylomandibular ligament': 'dây chằng trâm - hàm dưới',

    # --- Respiratory ---
    'superior lobe of lung': 'thùy trên phổi',
    'middle lobe of lung': 'thùy giữa phổi',
    'inferior lobe of lung': 'thùy dưới phổi',
    'mucosa of nasal cavity': 'niêm mạc ổ mũi',
    'quadrangular membrane': 'màng tứ giác',
    'cricopharyngeal ligament': 'dây chằng nhẫn - hầu',

    # --- Digestive / endocrine / reproductive ---
    'nasopharynx': 'phần mũi hầu',
    'oropharynx': 'phần miệng hầu',
    'laryngopharynx': 'phần thanh quản hầu',
    'soft palate': 'khẩu cái mềm',
    'uvula of palate': 'lưỡi gà',
    'parotid gland': 'tuyến mang tai',
    'accessory parotid gland': 'tuyến mang tai phụ',
    'parotid duct': 'ống tuyến mang tai',
    'submandibular duct': 'ống tuyến dưới hàm',
    'bile duct': 'ống mật chủ',
    'accessory pancreatic duct': 'ống tụy phụ',
    'lesser omentum': 'mạc nối nhỏ',
    'sigmoid colon': 'đại tràng sigma',
    'thyroid gland': 'tuyến giáp',
    'superior parathyroid gland': 'tuyến cận giáp trên',
    'inferior parathyroid gland': 'tuyến cận giáp dưới',
    'ejaculatory duct': 'ống phóng tinh',

    # --- Sensory ---
    'malleus': 'xương búa',
    'incus': 'xương đe',
    'stapes': 'xương bàn đạp',
    'tympanic membrane': 'màng nhĩ',
    'auditory tube': 'vòi tai',
    'ampulla of lacrimal canaliculus': 'bóng tiểu quản lệ',
    'suspensory ligament of eyeball': 'dây chằng treo nhãn cầu',

    # --- Lymphoid ---
    'lymph node': 'hạch bạch huyết',
    'palatine tonsil': 'hạnh nhân khẩu cái',
    'node of arch of azygos vein': 'hạch cung tĩnh mạch đơn',
    'node of ligamentum arteriosum': 'hạch dây chằng động mạch',

    # --- Nervous ---
    'spinal cord': 'tủy sống',
    'cauda equina': 'đuôi ngựa',
    'falx cerebri': 'liềm đại não',
    'spinal ganglion': 'hạch gai',
    'anterior root of spinal nerve': 'rễ trước thần kinh sống',
    'posterior root of spinal nerve': 'rễ sau thần kinh sống',
    'sympathetic trunk': 'thân giao cảm',
    'ganglia of sympathetic trunk': 'các hạch thân giao cảm',
    'sympathetic nerves': 'các thần kinh giao cảm',
    'olfactory nerve': 'thần kinh khứu giác',
    'oculomotor nerve': 'thần kinh vận nhãn',
    'trigeminal nerve': 'thần kinh sinh ba',
    'sensory root of trigeminal nerve': 'rễ cảm giác thần kinh sinh ba',
    'motor root of trigeminal nerve': 'rễ vận động thần kinh sinh ba',
    'maxillary nerve': 'thần kinh hàm trên',
    'meningeal branch of maxillary nerve': 'nhánh màng não thần kinh hàm trên',
    'anterior division of mandibular nerve': 'thân trước thần kinh hàm dưới',
    'posterior division of mandibular nerve': 'thân sau thần kinh hàm dưới',
    'buccal nerve': 'thần kinh má',
    'lingual nerve': 'thần kinh lưỡi',
    'inferior alveolar nerve': 'thần kinh huyệt răng dưới',
    'mental nerve': 'thần kinh cằm',
    'nerve to mylohyoid': 'thần kinh cơ hàm - móng',
    'abducens nerve': 'thần kinh vận nhãn ngoài',
    'facial nerve': 'thần kinh mặt',
    'chorda tympani': 'thừng nhĩ',
    'vestibulocochlear nerve': 'thần kinh tiền đình - ốc tai',
    'glossopharyngeal nerve': 'thần kinh thiệt hầu',
    'vagus nerve': 'thần kinh lang thang',
    'accessory nerve': 'thần kinh phụ',
    'hypoglossal nerve': 'thần kinh hạ thiệt',
    'roots of brachial plexus': 'các rễ đám rối cánh tay',
    'superior trunk of brachial plexus': 'thân trên đám rối cánh tay',
    'middle trunk of brachial plexus': 'thân giữa đám rối cánh tay',
    'inferior trunk of brachial plexus': 'thân dưới đám rối cánh tay',
    'anterior division of superior trunk of brachial plexus': 'ngành trước thân trên đám rối cánh tay',
    'anterior division of middle trunk of brachial plexus': 'ngành trước thân giữa đám rối cánh tay',
    'anterior division of inferior trunk of brachial plexus': 'ngành trước thân dưới đám rối cánh tay',
    'posterior division of superior trunk of brachial plexus': 'ngành sau thân trên đám rối cánh tay',
    'posterior division of middle trunk of brachial plexus': 'ngành sau thân giữa đám rối cánh tay',
    'posterior division of inferior trunk of brachial plexus': 'ngành sau thân dưới đám rối cánh tay',
    'posterior cord of brachial plexus': 'bó sau đám rối cánh tay',
    'dorsal scapular nerve': 'thần kinh lưng vai',
    'suprascapular nerve': 'thần kinh trên vai',
    'subclavian nerve': 'thần kinh dưới đòn',
    'long thoracic nerve': 'thần kinh ngực dài',
    'lateral pectoral nerve': 'thần kinh ngực ngoài',
    'medial pectoral nerve': 'thần kinh ngực trong',
    'superior subscapular nerve': 'thần kinh dưới vai trên',
    'inferior subscapular nerve': 'thần kinh dưới vai dưới',
    'thoracodorsal nerve': 'thần kinh ngực - lưng',
    'axillary nerve': 'thần kinh nách',
    'muscular branches of axillary nerve': 'các nhánh cơ thần kinh nách',
    'superior lateral brachial cutaneous nerve': 'thần kinh bì cánh tay ngoài trên',
    'inferior lateral brachial cutaneous nerve': 'thần kinh bì cánh tay ngoài dưới',
    'medial brachial cutaneous nerve': 'thần kinh bì cánh tay trong',
    'medial antebrachial cutaneous nerve': 'thần kinh bì cẳng tay trong',
    'anterior branch of medial antebrachial cutaneous nerve': 'nhánh trước thần kinh bì cẳng tay trong',
    'posterior branch of medial antebrachial cutaneous nerve': 'nhánh sau thần kinh bì cẳng tay trong',
    'lateral antebrachial cutaneous nerve': 'thần kinh bì cẳng tay ngoài',
    'posterior antebrachial cutaneous nerve': 'thần kinh bì cẳng tay sau',
    'musculocutaneous nerve': 'thần kinh cơ bì',
    'radial nerve': 'thần kinh quay',
    'muscular branches of radial nerve': 'các nhánh cơ thần kinh quay',
    'deep branch of radial nerve': 'nhánh sâu thần kinh quay',
    'superficial branch of radial nerve': 'nhánh nông thần kinh quay',
    'dorsal digital branches of radial nerve': 'các nhánh mu ngón tay thần kinh quay',
    'posterior interosseous nerve of forearm': 'thần kinh gian cốt sau cẳng tay',
    'median nerve': 'thần kinh giữa',
    'muscular branches of median nerve': 'các nhánh cơ thần kinh giữa',
    'anterior interosseous nerve of forearm': 'thần kinh gian cốt trước cẳng tay',
    'palmar branch of median nerve': 'nhánh gan tay thần kinh giữa',
    'common palmar digital branches of median nerve': 'các nhánh gan ngón tay chung thần kinh giữa',
    'proper palmar digital branches of median nerve': 'các nhánh gan ngón tay riêng thần kinh giữa',
    'communicating branch of median nerve with ulnar nerve': 'nhánh nối thần kinh giữa với thần kinh trụ',
    'ulnar nerve': 'thần kinh trụ',
    'muscular branches of ulnar nerve': 'các nhánh cơ thần kinh trụ',
    'dorsal branch of ulnar nerve': 'nhánh mu tay thần kinh trụ',
    'dorsal digital branches of ulnar nerve': 'các nhánh mu ngón tay thần kinh trụ',
    'palmar branch of ulnar nerve': 'nhánh gan tay thần kinh trụ',
    'superficial branch of ulnar nerve': 'nhánh nông thần kinh trụ',
    'deep branch of ulnar nerve': 'nhánh sâu thần kinh trụ',
    'common palmar digital branches of ulnar nerve': 'các nhánh gan ngón tay chung thần kinh trụ',
    'proper palmar digital branches of ulnar nerve': 'các nhánh gan ngón tay riêng thần kinh trụ',
    'intercostal nerves': 'các thần kinh gian sườn',
    'iliohypogastric nerve': 'thần kinh chậu - hạ vị',
    'ilio-inguinal nerve': 'thần kinh chậu - bẹn',
    'genitofemoral nerve': 'thần kinh sinh dục - đùi',
    'genital branch of genitofemoral nerve': 'nhánh sinh dục thần kinh sinh dục - đùi',
    'femoral branch of genitofemoral nerve': 'nhánh đùi thần kinh sinh dục - đùi',
    'lateral femoral cutaneous nerve': 'thần kinh bì đùi ngoài',
    'femoral nerve': 'thần kinh đùi',
    'anterior cutaneous branches of femoral nerve': 'các nhánh bì trước thần kinh đùi',
    'saphenous nerve': 'thần kinh hiển',
    'infrapatellar branch of saphenous nerve': 'nhánh dưới bánh chè thần kinh hiển',
    'medial crural cutaneous branches of saphenous nerve': 'các nhánh bì cẳng chân trong thần kinh hiển',
    'obturator nerve': 'thần kinh bịt',
    'anterior branch of obturator nerve': 'nhánh trước thần kinh bịt',
    'posterior branch of obturator nerve': 'nhánh sau thần kinh bịt',
    'superior gluteal nerve': 'thần kinh mông trên',
    'nerve to piriformis': 'thần kinh cơ hình lê',
    'nerve to quadratus femoris': 'thần kinh cơ vuông đùi',
    'posterior femoral cutaneous nerve': 'thần kinh bì đùi sau',
    'anterior root of posterior femoral cutaneous nerve': 'rễ trước thần kinh bì đùi sau',
    'posterior root of posterior femoral cutaneous nerve': 'rễ sau thần kinh bì đùi sau',
    'pudendal nerve': 'thần kinh thẹn',
    'sciatic nerve': 'thần kinh ngồi',
    'tibial nerve': 'thần kinh chày',
    'medial sural cutaneous nerve': 'thần kinh bì bắp chân trong',
    'sural nerve': 'thần kinh bắp chân',
    'medial plantar nerve': 'thần kinh gan chân trong',
    'lateral plantar nerve': 'thần kinh gan chân ngoài',
    'common plantar digital branches of medial plantar nerve': 'các nhánh gan ngón chân chung thần kinh gan chân trong',
    'common plantar digital branches of lateral plantar nerve': 'các nhánh gan ngón chân chung thần kinh gan chân ngoài',
    'proper plantar digital branches of medial plantar nerve': 'các nhánh gan ngón chân riêng thần kinh gan chân trong',
    'proper plantar digital branches of lateral plantar nerve': 'các nhánh gan ngón chân riêng thần kinh gan chân ngoài',
    'common fibular nerve': 'thần kinh mác chung',
    'sural communicating branch of common fibular nerve': 'nhánh nối bắp chân thần kinh mác chung',
    'superficial fibular nerve': 'thần kinh mác nông',
    'deep fibular nerve': 'thần kinh mác sâu',
    'muscular branches of deep fibular nerve': 'các nhánh cơ thần kinh mác sâu',
    'dorsal digital branches of deep fibular nerve': 'các nhánh mu ngón chân thần kinh mác sâu',
    'dorsal digital branches of superficial fibular nerve': 'các nhánh mu ngón chân thần kinh mác nông',
    'medial dorsal cutaneous nerve of foot': 'thần kinh bì mu chân trong',
    'intermediate dorsal cutaneous nerve of foot': 'thần kinh bì mu chân giữa',

    # --- Vessels ---
    'basilar venous plexus': 'đám rối tĩnh mạch nền',
    'cavernous sinus': 'xoang hang',
    'anterior intercavernous sinus': 'xoang gian hang trước',
    'posterior intercavernous sinus': 'xoang gian hang sau',
    'superior sagittal sinus': 'xoang dọc trên',
    'inferior sagittal sinus': 'xoang dọc dưới',
    'straight sinus': 'xoang thẳng',
    'transverse sinus': 'xoang ngang',
    'sigmoid sinus': 'xoang sigma',
    'occipital sinus': 'xoang chẩm',
    'superior petrosal sinus': 'xoang đá trên',
    'inferior petrosal sinus': 'xoang đá dưới',
    'accessory branch of middle meningeal artery': 'nhánh phụ động mạch màng não giữa',
    'anterior division of internal iliac artery': 'thân trước động mạch chậu trong',
    'posterior division of internal iliac artery': 'thân sau động mạch chậu trong',
    'anterior division of retromandibular vein': 'nhánh trước tĩnh mạch sau hàm dưới',
    'posterior division of retromandibular vein': 'nhánh sau tĩnh mạch sau hàm dưới',
    'anterior septal branches of anterior ethmoidal artery': 'các nhánh vách trước động mạch sàng trước',
    'septal branches of posterior ethmoidal artery': 'các nhánh vách động mạch sàng sau',
    'posterior lateral nasal branches of sphenopalatine artery': 'các nhánh mũi ngoài sau động mạch bướm - khẩu cái',
    'posterior septal branches of sphenopalatine artery': 'các nhánh vách sau động mạch bướm - khẩu cái',
    'artery of pterygoid canal': 'động mạch ống chân bướm',
    'calcaneal branches of fibular artery': 'các nhánh gót động mạch mác',
    'colic branch of ileocolic artery': 'nhánh đại tràng động mạch hồi - đại tràng',
    'deep artery of penis': 'động mạch sâu dương vật',
    'deep branch of transverse cervical artery': 'nhánh sâu động mạch cổ ngang',
    'superficial branch of transverse cervical artery': 'nhánh nông động mạch cổ ngang',
    'dorsal carpal anastomosis': 'mạng mạch mu cổ tay',
    'patellar anastomosis': 'mạng mạch bánh chè',
    'dorsal digital arteries of hand': 'các động mạch mu ngón tay',
    'dorsal digital veins of hand': 'các tĩnh mạch mu ngón tay',
    'dorsal digital veins of foot': 'các tĩnh mạch mu ngón chân',
    'intercapitular veins of foot': 'các tĩnh mạch gian chỏm bàn chân',
    'frontal branch of superficial temporal artery': 'nhánh trán động mạch thái dương nông',
    'iliacus branch of iliolumbar artery': 'nhánh chậu động mạch chậu - thắt lưng',
    'lumbar branch of iliolumbar artery': 'nhánh thắt lưng động mạch chậu - thắt lưng',
    'spinal branch of iliolumbar artery': 'nhánh tủy sống động mạch chậu - thắt lưng',
    'mental branch of inferior alveolar artery': 'nhánh cằm động mạch huyệt răng dưới',
    'mylohyoid branch of inferior alveolar artery': 'nhánh hàm - móng động mạch huyệt răng dưới',
    'palmar carpal branch of radial artery': 'nhánh gan cổ tay động mạch quay',
    'perforating branches of plantar metatarsal arteries': 'các nhánh xiên động mạch gan đốt bàn chân',
    'perforating femoral arteries': 'các động mạch xiên đùi',
    'long posterior ciliary arteries': 'các động mạch mi sau dài',
    'short posterior ciliary arteries': 'các động mạch mi sau ngắn',
}

ZA_MUSCLES = {
    'buccinator': 'mút',
    'corrugator supercilii': 'cau mày',
    'depressor anguli oris': 'hạ góc miệng',
    'depressor labii inferioris': 'hạ môi dưới',
    'depressor septi nasi': 'hạ vách mũi',
    'extensor digitorum brevis': 'duỗi các ngón chân ngắn',
    'frontalis': 'trán',
    'occipitalis': 'chẩm',
    'temporoparietalis': 'thái dương - đỉnh',
    'internal abdominal oblique': 'chéo bụng trong',
    'transversus abdominis': 'ngang bụng',
    'rectus abdominis': 'thẳng bụng',
    'pyramidalis': 'tháp',
    'quadratus lumborum': 'vuông thắt lưng',
    'latissimus dorsi': 'lưng rộng',
    'levator anguli oris': 'nâng góc miệng',
    'levator labii superioris': 'nâng môi trên',
    'levator nasolabialis': 'nâng môi trên cánh mũi',
    'medial pterygoid': 'chân bướm trong',
    'lateral pterygoid': 'chân bướm ngoài',
    'masseter': 'cắn',
    'orbicularis oculi': 'vòng mắt',
    'mentalis': 'cằm',
    'multifidus colli': 'nhiều chân cổ',
    'multifidus thoracis': 'nhiều chân ngực',
    'multifidus lumborum': 'nhiều chân thắt lưng',
    'nasalis': 'mũi',
    'orbicularis oris': 'vòng miệng',
    'procerus': 'mảnh khảnh',
    'risorius': 'cười',
    'temporalis': 'thái dương',
    'zygomaticus major': 'gò má lớn',
    'zygomaticus minor': 'gò má nhỏ',
    'infraspinatus': 'dưới gai',
}

ZA_MUSCULAR_TERMS = {
    'dorsal interossei muscles of foot': 'các cơ gian cốt mu chân',
    'inferior head of lateral pterygoid': 'đầu dưới cơ chân bướm ngoài',
    'superior head of lateral pterygoid': 'đầu trên cơ chân bướm ngoài',
    'deep part of masseter': 'phần sâu cơ cắn',
    'superficial part of masseter': 'phần nông cơ cắn',
    'orbital part of orbicularis oculi': 'phần ổ mắt cơ vòng mắt',
    'palpebral part of orbicularis oculi': 'phần mi cơ vòng mắt',
    'tendon of extensor digitorum longus': 'gân cơ duỗi các ngón chân dài',
    'extensor retinaculum of wrist': 'mạc giữ gân duỗi cổ tay',
    'flexor retinaculum of ankle': 'mạc giữ gân gấp cổ chân',
    'superior extensor retinaculum of ankle': 'mạc giữ gân duỗi trên cổ chân',
    'inferior extensor retinaculum of ankle': 'mạc giữ gân duỗi dưới cổ chân',
    'superior fibular retinaculum': 'mạc giữ gân cơ mác trên',
    'inferior fibular retinaculum': 'mạc giữ gân cơ mác dưới',
    'lateral patellar retinaculum': 'mạc giữ bánh chè ngoài',
    'medial patellar retinaculum': 'mạc giữ bánh chè trong',
    'palmar aponeurosis': 'cân gan tay',
    'plantar aponeurosis': 'cân gan chân',
    'iliopectineal arch': 'cung chậu - lược',
    'inguinal ligament': 'dây chằng bẹn',
    'superficial transverse metacarpal ligament': 'dây chằng ngang nông đốt bàn tay',
    'superficial transverse metatarsal ligament': 'dây chằng ngang nông đốt bàn chân',
    'cruciform part of fibrous sheath of digit of hand': 'phần chữ thập bao sợi ngón tay',
    # Bursae.
    'anserine bursa': 'túi thanh mạc chân ngỗng',
    'bicipitoradial bursa': 'túi thanh mạc nhị đầu - quay',
    'coracobrachial bursa': 'túi thanh mạc cơ quạ - cánh tay',
    'iliopectineal bursa': 'túi thanh mạc chậu - lược',
    'intermuscular gluteal bursae': 'các túi thanh mạc gian cơ mông',
    'semimembranosus bursa': 'túi thanh mạc cơ bán màng',
    'subacromial bursa': 'túi thanh mạc dưới mỏm cùng vai',
    'subdeltoid bursa': 'túi thanh mạc dưới cơ delta',
    'subcutaneous acromial bursa': 'túi thanh mạc dưới da mỏm cùng vai',
    'subcutaneous bursa of lateral malleolus': 'túi thanh mạc dưới da mắt cá ngoài',
    'subcutaneous bursa of medial malleolus': 'túi thanh mạc dưới da mắt cá trong',
    'subcutaneous bursa of tuberosity of tibia': 'túi thanh mạc dưới da lồi củ chày',
    'subcutaneous calcaneal bursa': 'túi thanh mạc dưới da gót',
    'subcutaneous infrapatellar bursa': 'túi thanh mạc dưới da dưới bánh chè',
    'subcutaneous prepatellar bursa': 'túi thanh mạc dưới da trước bánh chè',
    'subcutaneous trochanteric bursa': 'túi thanh mạc dưới da mấu chuyển',
    'subfacial prepatellar bursa': 'túi thanh mạc dưới mạc trước bánh chè',
    'subtendinous prepatellar bursa': 'túi thanh mạc dưới gân trước bánh chè',
    'subtendinous calcaneal bursa': 'túi thanh mạc dưới gân gót',
    'deep infrapatellar bursa': 'túi thanh mạc dưới bánh chè sâu',
    'suprapatellar bursa': 'túi thanh mạc trên bánh chè',
    'lateral subtendinous bursa of gastrocnemius': 'túi thanh mạc dưới gân ngoài cơ bụng chân',
    'medial subtendinous bursa of gastrocnemius': 'túi thanh mạc dưới gân trong cơ bụng chân',
    'inferior subtendinous bursa of biceps femoris': 'túi thanh mạc dưới gân dưới cơ nhị đầu đùi',
    'superior bursa of biceps femoris': 'túi thanh mạc trên cơ nhị đầu đùi',
    # Tendon sheaths.
    'common flexor tendon sheath': 'bao gân gấp chung',
    'common tendon sheath of fibularis muscles': 'bao gân chung các cơ mác',
    'intertubercular tendon sheath': 'bao gân gian củ',
    'plantar tendon sheath of fibularis longus': 'bao gân gan chân cơ mác dài',
    'synovial sheaths of digits of hand': 'các bao hoạt dịch ngón tay',
    'tendon sheath of abductor pollicis longus and extensor pollicis brevis':
        'bao gân cơ dạng ngón cái dài và cơ duỗi ngón cái ngắn',
    'tendon sheath of extensor digitorum and extensor indicis': 'bao gân cơ duỗi các ngón tay và cơ duỗi ngón trỏ',
    'tendon sheath of extensors carpi radialis': 'bao gân các cơ duỗi cổ tay quay',
    'tendon sheath of extensor digiti minimi manus': 'bao gân cơ duỗi ngón út',
}

ZA_VESSELS = {
    'external carotid': 'cảnh ngoài', 'external jugular': 'cảnh ngoài', 'anterior jugular': 'cảnh trước',
    'facial': 'mặt', 'common facial': 'mặt chung', 'angular': 'góc', 'maxillary': 'hàm trên',
    'occipital': 'chẩm', 'lingual': 'lưỡi', 'lacrimal': 'lệ', 'buccal': 'má', 'submental': 'dưới cằm',
    'retromandibular': 'sau hàm dưới', 'superficial temporal': 'thái dương nông',
    'middle meningeal': 'màng não giữa', 'infra-orbital': 'dưới ổ mắt', 'supra-orbital': 'trên ổ mắt',
    'supratrochlear': 'trên ròng rọc', 'anterior ethmoidal': 'sàng trước', 'posterior ethmoidal': 'sàng sau',
    'ascending pharyngeal': 'hầu lên', 'descending palatine': 'khẩu cái xuống', 'greater palatine': 'khẩu cái lớn',
    'inferior alveolar': 'huyệt răng dưới', 'posterior superior alveolar': 'huyệt răng trên sau',
    'superior labial': 'môi trên', 'inferior labial': 'môi dưới', 'superior ophthalmic': 'mắt trên',
    'inferior ophthalmic': 'mắt dưới', 'posterior auricular': 'tai sau', 'transverse facial': 'ngang mặt',
    'central retinal': 'trung tâm võng mạc', 'anterior deep temporal': 'thái dương sâu trước',
    'posterior deep temporal': 'thái dương sâu sau', 'superior thyroid': 'giáp trên',
    'deep external pudendal': 'thẹn ngoài sâu', 'superficial external pudendal': 'thẹn ngoài nông',
    'external pudendal': 'thẹn ngoài', 'superior anorectal': 'trực tràng trên',
    'supreme intercostal': 'gian sườn trên cùng', 'posterior interosseous': 'gian cốt sau',
    'dorsal metatarsal': 'mu đốt bàn chân', 'medial plantar': 'gan chân trong', 'gastro-omental': 'vị - mạc nối',
}

# Lymph nodes: "<x> node(s)" -> "hạch <x>" / "các hạch <x>".
NODES = {
    'anterior axillary': 'nách trước', 'posterior axillary': 'nách sau', 'lateral axillary': 'nách ngoài',
    'central axillary': 'nách trung tâm', 'apical axillary': 'nách đỉnh', 'interpectoral': 'gian ngực',
    'infraclavicular': 'dưới đòn', 'supraclavicular': 'trên đòn', 'brachial': 'cánh tay',
    'cubital': 'khuỷu', 'supratrochlear': 'trên ròng rọc', 'occipital': 'chẩm', 'mastoid': 'chũm',
    'pre-auricular': 'trước tai', 'infra-auricular': 'dưới tai', 'superficial parotid': 'mang tai nông',
    'intraglandular parotid': 'trong tuyến mang tai', 'nasolabial': 'mũi - môi', 'buccinator': 'cơ mút',
    'mandibular': 'hàm dưới', 'submandibular': 'dưới hàm', 'submental': 'dưới cằm',
    'retropharyngeal': 'sau hầu', 'superficial anterior cervical': 'cổ trước nông',
    'superficial lateral cervical': 'cổ bên nông', 'inferior deep lateral cervical': 'cổ bên sâu dưới',
    'jugulodigastric': 'cảnh - hai bụng', 'lateral superior jugular': 'cảnh trên ngoài',
    'anterior inferior jugular': 'cảnh dưới trước', 'thyroid': 'tuyến giáp', 'pretracheal': 'trước khí quản',
    'paratracheal cervical': 'cạnh khí quản cổ', 'paratracheal thoracic': 'cạnh khí quản ngực',
    'brachiocephalic': 'cánh tay đầu', 'superior tracheobronchial': 'khí - phế quản trên',
    'inferior tracheobronchial': 'khí - phế quản dưới', 'intrapulmonary': 'trong phổi',
    'juxta-oesophageal': 'cạnh thực quản', 'prepericardial': 'trước màng ngoài tim',
    'lateral pericardial': 'bên màng ngoài tim', 'parasternal': 'cạnh ức', 'intercostal': 'gian sườn',
    'prevertebral': 'trước cột sống', 'superior diaphragmatic': 'hoành trên',
    'inferior diaphragmatic': 'hoành dưới', 'pre-aortic': 'trước động mạch chủ',
    'retro-aortic': 'sau động mạch chủ', 'lateral aortic': 'bên động mạch chủ',
    'subaortic': 'dưới động mạch chủ', 'precaval': 'trước tĩnh mạch chủ', 'retrocaval': 'sau tĩnh mạch chủ',
    'lateral caval': 'bên tĩnh mạch chủ', 'intermediate lumbar': 'thắt lưng trung gian',
    'coeliac': 'thân tạng', 'gastric': 'vị', 'gastro-omental': 'vị - mạc nối', 'splenic': 'lách',
    'superior pancreatic': 'tụy trên', 'inferior pancreatic': 'tụy dưới',
    'superior pancreaticoduodenal': 'tụy - tá tràng trên', 'suprapyloric': 'trên môn vị',
    'subpyloric': 'dưới môn vị', 'retropyloric': 'sau môn vị', 'cystic': 'túi mật',
    'central superior mesenteric': 'mạc treo tràng trên trung tâm',
    'juxta-intestinal mesenteric': 'mạc treo cạnh ruột',
    'paracolic superior mesenteric': 'mạc treo tràng trên cạnh đại tràng', 'ileocolic': 'hồi - đại tràng',
    'precaecal': 'trước manh tràng', 'retrocaecal': 'sau manh tràng', 'appendicular': 'ruột thừa',
    'colic': 'đại tràng', 'middle colic': 'đại tràng giữa', 'sigmoid': 'sigma', 'pararectal': 'cạnh trực tràng',
    'lateral common iliac': 'chậu chung ngoài', 'medial common iliac': 'chậu chung trong',
    'intermediate common iliac': 'chậu chung trung gian', 'medial external iliac': 'chậu ngoài trong',
    'intermediate external iliac': 'chậu ngoài trung gian', 'medial lacunar': 'khuyết mạch trong',
    'intermediate lacunar': 'khuyết mạch trung gian', 'lateral lacunar': 'khuyết mạch ngoài',
    'obturator': 'bịt', 'superior gluteal': 'mông trên', 'inferior gluteal': 'mông dưới',
    'lateral sacral': 'cùng bên', 'median sacral': 'cùng giữa', 'inferior epigastric': 'thượng vị dưới',
    'prevesical': 'trước bàng quang', 'postvesical': 'sau bàng quang', 'lateral vesical': 'bên bàng quang',
    'superomedial superficial inguinal': 'bẹn nông trên trong',
    'superolateral superficial inguinal': 'bẹn nông trên ngoài',
    'inferior superficial inguinal': 'bẹn nông dưới', 'proximal deep inguinal': 'bẹn sâu gần',
    'intermediate deep inguinal': 'bẹn sâu trung gian', 'superficial popliteal': 'khoeo nông',
    'deep popliteal': 'khoeo sâu', 'anterior tibial': 'chày trước', 'posterior tibial': 'chày sau',
    'fibular': 'mác',
}

TERMS.update(ZA_TERMS)
TERMS.update(ZA_MUSCULAR_TERMS)
MUSCLES.update(ZA_MUSCLES)
VESSELS.update(ZA_VESSELS)

# "<structure> of <muscle>" for bursae and tendon sheaths.
MUSCLE_BURSAE = {
    'subtendinous bursa of': 'túi thanh mạc dưới gân cơ',
    'trochanteric bursa of': 'túi thanh mạc mấu chuyển cơ',
    'sciatic bursa of': 'túi thanh mạc ngồi cơ',
    'bursa of': 'túi thanh mạc cơ',
    'tendon sheath of': 'bao gân cơ',
}

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

    m = re.fullmatch(r'(.+) (artery|vein|arteries|veins)', n)
    if m and m.group(1) in VESSELS:
        kind = 'động mạch' if m.group(2).startswith('arter') else 'tĩnh mạch'
        many = 'các ' if m.group(2).endswith('s') else ''
        return f'{many}{kind} {VESSELS[m.group(1)]}'

    m = re.fullmatch(r'(.+) (node|nodes)', n)
    if m and m.group(1) in NODES:
        return f'{"các hạch" if m.group(2) == "nodes" else "hạch"} {NODES[m.group(1)]}'

    m = re.fullmatch(r'(subtendinous bursa of|trochanteric bursa of|sciatic bursa of|bursa of|tendon sheath of) (.+)', n)
    if m and m.group(2) in MUSCLES:
        return f'{MUSCLE_BURSAE[m.group(1)]} {MUSCLES[m.group(2)]}'

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
