import { GameBoardType } from "./game-board-type";
import { DefaultGradients } from "../helpers/gradients";
import { TranslateService } from "@ngx-translate/core";

type LanguageString = Record<string, string>;

export class Settings {
	highlightColor: string;
	elementSize: number;
	gameBoardColumns: number;
	gameBoardRows: number;
	minValue: number;
	maxValue: number;
	minSelected: number;
	imageMode: boolean;
	basicInstructions: LanguageString;
	advancedInstructions: LanguageString;
	defaultProductionType: number;
	calcUrl: string;
	mode: 'GRID' | 'SVG';
	infiniteLevels: boolean;
	productionTypes: { id: number, name: LanguageString, fieldColor: string, urlToIcon: string, maxElements: number }[] = [];
	maps: { id: string, name: LanguageString, gradient: DefaultGradients, customColorId: string, gameBoardType: GameBoardType, productionTypes: number[], urlToData: string }[] = [];
	customColors: { id: string, colors: { number: number, color: string }[] }[];
	basicInstructionsImageUrl: string;
	advancedInstructionsImageUrl: string;

	constructor(
		private translate: TranslateService,
		data: any
	) {
		this.mapData(data);
	}

	mapData(data: any) {
		if (!data) return;
		this.elementSize = data.elementSize;
		this.gameBoardColumns = data.gameBoardColumns;
		this.gameBoardRows = data.gameBoardRows;
		this.imageMode = data.imageMode;
		this.defaultProductionType = Number.parseInt(data.defaultProductionType);
		this.mode = data.mapMode == "svg" ? 'SVG' : 'GRID';
		this.infiniteLevels = data.infiniteLevels;
		this.highlightColor = data.highlightColor;
		this.basicInstructions = data.basicInstructions;
		this.advancedInstructions = data.advancedInstructions;
		this.calcUrl = data.calcUrl;
		this.productionTypes = data.productionTypes.map((o: any) => ({ id: Number.parseInt(o.id), name: o.name, fieldColor: o.fieldColor, urlToIcon: o.urlToIcon, maxElements: o.maxElements }));
		this.maps = data.maps.map((o: any) => ({ id: o.id, name: o.name, gradient: convertGradient(o.gradient), customColorId: o.customColorId, gameBoardType: convertGameBoardType(o.gameBoardType), productionTypes: o.productionTypes.map((p: any) => Number.parseInt(p)), urlToData: o.urlToData }));
		this.customColors = data.customColors;
		this.basicInstructionsImageUrl = data.basicInstructionsImageUrl;
		this.advancedInstructionsImageUrl = data.advancedInstructionsImageUrl;
		this.minValue = data.minValue;
		this.maxValue = data.maxValue;
		this.minSelected = data.minSelected;

		this.translate.getLangs().forEach((lang) => {
			this.maps.forEach(o => {
				let translation = {} as any;
				translation["map_name_" + o.id] = o.name[lang];
				this.translate.setTranslation(lang, translation, true);
			});
			this.productionTypes.forEach(o => {
				let translation = {} as any;
				translation["production_type_" + o.id] = o.name[lang];
				this.translate.setTranslation(lang, translation, true);
			});
			let translation = {} as any;
			translation["basic_instructions"] = this.basicInstructions[lang];
			translation["advanced_instructions"] = this.advancedInstructions[lang];
			translation["title"] = data.title[lang];
			this.translate.setTranslation(lang, translation, true);
		});
	}
}

const convertGameBoardType = (type: string) => {
	switch (type) {
		case "Suitability": return GameBoardType.SuitabilityMap;
		case "Consequence": return GameBoardType.ConsequenceMap;
		case "Drawing": return GameBoardType.DrawingMap;
		case "Background": return GameBoardType.BackgroundMap;
		default: return GameBoardType.SuitabilityMap;
	}
};
const convertGradient = (gradientName: string) => gradientName as unknown as DefaultGradients;
