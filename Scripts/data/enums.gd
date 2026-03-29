## 全局枚举定义 v4：竞选大师
class_name Enums

## 素材类型
enum MaterialType { RECORD, PROMISE, DIRT, EMOTION }

## 议题
enum Topic { JOBS, TECH, AGRICULTURE, ECONOMY, EDUCATION, NONE }

## 广告类型（10种，由两张素材组合决定）
enum AdType {
	RECORD_REPORT,     ## 政绩+政绩 = 执政报告
	POLICY_BLUEPRINT,  ## 政绩+承诺 = 施政蓝图
	TOUCHING_STORY,    ## 政绩+煽情 = 感人故事
	INVESTIGATION,     ## 政绩+黑料 = 调查报告
	EMPTY_CHECK,       ## 承诺+承诺 = 空头支票
	CAMPAIGN_SPEECH,   ## 承诺+煽情 = 竞选演说
	COMPARISON_AD,     ## 承诺+黑料 = 对比广告
	SCANDAL_COMBO,     ## 黑料+黑料 = 丑闻连环锤
	FEAR_AD,           ## 黑料+煽情 = 恐惧广告
	POPULIST_RALLY,    ## 煽情+煽情 = 民粹煽动
}

## 素材类型名称
static func material_name(t: MaterialType) -> String:
	match t:
		MaterialType.RECORD: return "政绩"
		MaterialType.PROMISE: return "承诺"
		MaterialType.DIRT: return "黑料"
		MaterialType.EMOTION: return "煽情"
	return "?"

## 议题名称
static func topic_name(t: Topic) -> String:
	match t:
		Topic.JOBS: return "就业"
		Topic.TECH: return "科技"
		Topic.AGRICULTURE: return "农业"
		Topic.ECONOMY: return "经济"
		Topic.EDUCATION: return "教育"
		Topic.NONE: return "无"
	return "?"

## 广告类型名称
static func ad_name(t: AdType) -> String:
	match t:
		AdType.RECORD_REPORT: return "执政报告"
		AdType.POLICY_BLUEPRINT: return "施政蓝图"
		AdType.TOUCHING_STORY: return "感人故事"
		AdType.INVESTIGATION: return "调查报告"
		AdType.EMPTY_CHECK: return "空头支票"
		AdType.CAMPAIGN_SPEECH: return "竞选演说"
		AdType.COMPARISON_AD: return "对比广告"
		AdType.SCANDAL_COMBO: return "丑闻连环锤"
		AdType.FEAR_AD: return "恐惧广告"
		AdType.POPULIST_RALLY: return "民粹煽动"
	return "?"

## 品质星号
static func quality_stars(q: int) -> String:
	match q:
		1: return "★"
		2: return "★★"
		3: return "★★★"
	return "?"
