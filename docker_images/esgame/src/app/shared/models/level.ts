import { ScoreEntry } from "src/app/services/score.service";
import { SelectedField } from "./field";
import { GameBoard } from "./game-board";

export class Level {
	levelNumber: number;
	gameBoards: GameBoard[] = [];
	selectedFields: SelectedField[];
	isReadOnly = false;
	showConsequenceMaps = false;
	scores: ScoreEntry[];
	scoreImage: string;
}