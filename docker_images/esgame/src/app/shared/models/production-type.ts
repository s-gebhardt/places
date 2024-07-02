import { GameBoard } from "./game-board";

export class ProductionType {
	fieldColor: string;
	suitabilityMap: GameBoard;
	consequenceMaps: GameBoard[] = [];
	image: string;
	maxElements: number;
	id: number;

	constructor(id: number, fieldColor: string, scoreMap: GameBoard, image : string, maxElements : number) {
		this.id = id;
		this.fieldColor = fieldColor;
		this.suitabilityMap = scoreMap;
		this.image = image;
		this.maxElements = maxElements;
	}

	getScore(ids: number[]) {
		let score = this.suitabilityMap.getScore(ids);
		let minusScore = this.consequenceMaps?.map(o => o.getScore(ids)).reduce((a, b) => a+b, 0) ?? 0;
		return score - minusScore;
	}
}