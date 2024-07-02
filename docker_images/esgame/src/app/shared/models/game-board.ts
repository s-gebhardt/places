import { Legend } from "./legend";
import { Field } from "./field";
import { GameBoardType } from "./game-board-type";

export class GameBoard {
	id: string;
	fields: Field[];
	gameBoardType: GameBoardType;
	legend: Legend | undefined;
	isSvg: boolean;
	width: number;
	height: number;
	background: string;
	background2: string;

	constructor(id: string, gameBoardType: GameBoardType, fields: Field[], legend?: Legend, isSvg = false, width = 0, height = 0, background = "", background2 = "") {
		this.id = id
		this.fields = fields;
		this.gameBoardType = gameBoardType;
		this.legend = legend;
		this.isSvg = isSvg;
		this.width = width;
		this.height = height;
		this.background = background;
		this.background2 = background2;
	}

	getScore(ids: number[]) {
		let scores = this.fields.filter(o => ids.some(p => o.id == p)).map(o => o.score);
		return scores.reduce((a, b) => a+b, 0);
	}

	get isPositive() : boolean {
		return this.gameBoardType == GameBoardType.SuitabilityMap;
	}
}

export enum GameBoardClickMode {
	Field = "FIELD",
	SelectBoard = "SELECTBOARD",
}