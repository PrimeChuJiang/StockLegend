## 股票数据定义，继承插件的 ItemData
class_name StockData
extends ItemData

## 行业
@export var industry: Tag
## 初始价格
@export var initial_price: float
## 价格波动类型
@export var volatility: Enums.Volatility

## 获取波动比例
func get_volatility_coefficient() -> float:
	match volatility:
		Enums.Volatility.LOW:
			return 0.5
		Enums.Volatility.MEDIUM:
			return 1.0
		Enums.Volatility.HIGH:
			return 1.5
	return 1.0

## 获取退市阈值
func get_delisting_threshold() -> float :
	return initial_price * 0.2
