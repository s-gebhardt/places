import { Injectable } from '@angular/core';
import { BehaviorSubject, combineLatest, switchMap, tap } from 'rxjs';
import { GameBoard } from '../shared/models/game-board';
import { GameBoardType } from '../shared/models/game-board-type';
import { Level } from '../shared/models/level';
import { Settings } from '../shared/models/settings';
import { ProductionType } from '../shared/models/production-type';
import { HighlightField, HighlightSide, SelectedField } from '../shared/models/field';
import { TiffService } from './tiff.service';
import { CustomColors } from '../shared/helpers/gradients';
import { ScoreService, ScoreEntry } from './score.service';
import { TranslateService } from '@ngx-translate/core';
import { ApiService } from './api.service';
import { CalculationResult } from '../shared/models/calculation-result';
import * as uuid from 'uuid';

@Injectable({
	providedIn: 'root'
})
export class GameService {
	private currentLevel = new BehaviorSubject<Level | null>(null);
	private highlightFields = new BehaviorSubject<HighlightField[]>([]);
	private selectedFields = new BehaviorSubject<SelectedField[]>([]);
	private notSelectedFields = new BehaviorSubject<SelectedField[]>([]);
	private currentlySelectedField = new BehaviorSubject<SelectedField | null>(null);
	private settings = new BehaviorSubject<Settings>(new Settings(this.translateService, null));
	private productionTypes = new BehaviorSubject<ProductionType[]>([]);
	private selectedProductionType = new BehaviorSubject<ProductionType | null>(null);
	private focusedGameBoard = new BehaviorSubject<GameBoard | null>(null);
	private helpWindow = new BehaviorSubject<boolean>(false);
	private loadingIndicator = new BehaviorSubject<boolean[]>([]);
	private levels: Level[] = [];
	private gameId = uuid.v4();
	private customColors: CustomColors[] = [];

	highlightFieldObs = this.highlightFields.asObservable();
	currentLevelObs = this.currentLevel.asObservable();
	settingsObs = this.settings.asObservable();
	productionTypesObs = this.productionTypes.asObservable();
	selectedProductionTypeObs = this.selectedProductionType.asObservable();
	selectedFieldsObs = this.selectedFields.asObservable().pipe(
		tap(o => {
			if (this.currentLevel.value) {
				this.currentLevel.value.selectedFields = o;
			}
			return o;
		})
	);
	notSelectedFieldsObs = this.notSelectedFields.asObservable();
	focusedGameBoardObs = this.focusedGameBoard.asObservable();
	currentlySelectedFieldObs = this.currentlySelectedField.asObservable();
	helpWindowObs = this.helpWindow.asObservable();
	loadingIndicatorObs = this.loadingIndicator.asObservable();

	constructor(
		private tiffService: TiffService,
		private scoreService: ScoreService,
		private translateService: TranslateService,
		private apiService: ApiService
	) { }

	highlightOnOtherFields(id: any) {
		let ids = this.getAssociatedFields(id);
		this.currentlySelectedField.next(new SelectedField(ids, this.selectedProductionType.value!));
		if (!this.canFieldBePlaced(ids)) {
			this.removeHighlight();
			return;
		}

		this.highlightFields.next(ids);
	}

	removeHighlight() {
		this.highlightFields.next([]);
		this.currentlySelectedField.next(null);
	}

	setSelectedProductionType(productionType: ProductionType) {
		this.selectedProductionType.next(productionType);
	}

	selectField(id: number) {
		let fields = this.getAssociatedFields(id);

		if (!this.canFieldBePlaced(fields)) {
			this.removeHighlight();
			return;
		}

		if (this.selectedProductionType.value != null) {
			let selectedField = new SelectedField(fields, this.selectedProductionType.value);
			this.selectedFields.next([...this.selectedFields.value, selectedField]);
		}
	}

	deselectField(id: number) {
		this.selectedFields.next(this.selectedFields.value.filter(o => !o.fields.map(f => f.id).includes(id)));
	}

	selectGameBoard(boardData: GameBoard) {
		this.focusedGameBoard.next(boardData);
	}

	goToNextLevel() {
		let currentHighest = this.levels[this.levels.length - 1];
		if (currentHighest == this.currentLevel.value) {
			if (this.settings.value.calcUrl) {
				this.loading(true);
				let inputData = {} as { allocation: { id: number, lulc: number }[], round: number, score: number, game_id: string};
				const allFields = [...this.selectedFields.value, ...this.notSelectedFields.value];
				inputData.allocation = allFields.map((o) => ({ id: o.fields[0].id, lulc: o.productionType?.id ?? this.settings.value.defaultProductionType }));
				inputData.round = this.currentLevel.value!.levelNumber;
				const entries = this.scoreService.createEmptyScoreEntry(this.currentLevel.value, [GameBoardType.SuitabilityMap]);
				this.scoreService.calculateScore(entries, this.selectedFields.value);
				const score = entries.reduce((a, b) => a + b.score, 0);
				inputData.score = entries.reduce((a, b) => a + b.score, 0);
				inputData.game_id = this.gameId;

				this.apiService.postRequest(this.settings.value.calcUrl, inputData).subscribe({
					next: (res) => {
						const convertedResult = res as CalculationResult;
						this.prepareNextLevel(convertedResult, score);
						this.loading(false);
					},
					error: (err) => {
						console.error(err);
						alert("Something went wrong, please try again later")
						this.loading(false);
					}
				});
			} else {
				this.prepareNextLevel();
			}

		} else {
			let lvl = this.levels.find(o => o.levelNumber == (this.currentLevel.value!.levelNumber + 1))!;
			const currentPt = this.productionTypes.value;

			currentPt.forEach(pt => { pt.consequenceMaps = []; });

			lvl.gameBoards.filter(c => c.gameBoardType == GameBoardType.ConsequenceMap).forEach(map => {
				const mapSettings = this.settings.value.maps.find(c => c.id == map.id)!;
				mapSettings.productionTypes.forEach(ptId => {
					currentPt.find(c => c.id == ptId)!.consequenceMaps.push(map);
				});
			});

			this.currentLevel.next(lvl);
			this.productionTypes.next(currentPt);
			this.selectedFields.next(lvl.selectedFields);
		}
	}

	goToPreviousLevel() {
		this.loading();
		let currentLowest = this.levels[0];

		if (currentLowest != this.currentLevel.value) {
			let lvl = this.levels.find(o => o.levelNumber == this.currentLevel.value!.levelNumber - 1)!;
			const currentPt = this.productionTypes.value;

			currentPt.forEach(pt => { pt.consequenceMaps = []; });

			lvl.gameBoards.filter(c => c.gameBoardType == GameBoardType.ConsequenceMap).forEach(map => {
				const mapSettings = this.settings.value.maps.find(c => c.id == map.id)!;
				mapSettings.productionTypes.forEach(ptId => {
					const pt = currentPt.find(c => c.id == ptId)!;
					pt.consequenceMaps.push(map);
				});
			});

			this.currentLevel.next(lvl);
			this.selectedFields.next(lvl.selectedFields);
			this.loading(false);
		}
	}

	prepareNextLevel(calculationResult: CalculationResult | undefined = undefined, previousScore: number | undefined = undefined) {
		this.loading();
		const level = new Level();
		const settings = this.settings.value;
		const previousLevel = this.currentLevel.value!;
		level.levelNumber = previousLevel.levelNumber + 1;
		level.showConsequenceMaps = true;
		this.levels.push(level);

		this.currentLevel.value!.isReadOnly = true;
		this.currentLevel.value!.selectedFields = this.selectedFields.value.map(o => {
			return Object.assign({}, o);
		});

		if (this.settings.value.mode == 'GRID') {
			const maps = settings.maps.filter(
				m => m.gameBoardType == GameBoardType.ConsequenceMap &&
					!previousLevel.gameBoards.map(o => o.id).includes(m.id));

			level.gameBoards.push(...previousLevel.gameBoards);


			combineLatest(maps.map(m => this.getGridGameBoard(m))).subscribe((gameBoards) => {
				level.gameBoards.push(...gameBoards);
				gameBoards.forEach(c => {
					let map = settings.maps.find(o => o.id == c.id);
					map!.productionTypes.forEach(p => {
						let productionType = this.productionTypes.value.find(o => o.id == p);
						productionType!.consequenceMaps.push(c);
					});
				});

				this.selectedFields.value.forEach(o => o.updateScore());

				this.currentLevel.next(level);
				this.selectedFields.next(this.selectedFields.value);
				this.loading(false);
			});
		} else if (this.settings.value.mode == 'SVG') {
			const overlay = this.currentLevel.value!.gameBoards.find(o => o.gameBoardType == GameBoardType.DrawingMap)!;
			const backgroundMap = settings.maps.find(o => o.gameBoardType == GameBoardType.BackgroundMap)!;

			const consequences = settings.maps.filter(
				m => m.gameBoardType == GameBoardType.ConsequenceMap);

			if (calculationResult) {
				consequences.forEach(m => m.urlToData = calculationResult.results.find(c => c.id == m.id)?.url!);
				calculationResult.results.forEach(c => c.score = isNaN(c.score) ? 0 : c.score);
				level.scores = [{ id: "all", score: previousScore!} , ...calculationResult.results.filter(c => c.id != "-1").map(c => ({ score: -((c.score ?? 0)*100), id: c.id } as ScoreEntry))];
			}

			const image = calculationResult?.results.find(c => c.id == "-1");
			if(image) {
				level.scoreImage = image.url;
			}

			level.gameBoards.push(...previousLevel.gameBoards.filter(c => c.gameBoardType != GameBoardType.ConsequenceMap));

			let customColors = this.customColors.find(o => o.id == backgroundMap.customColorId)!;
			customColors.addTransparencyToColors("3F"); // 25% opacity

			combineLatest([
				this.tiffService.getSvgBackground(backgroundMap.urlToData, settings.minValue, settings.maxValue, customColors),
				...consequences.map(m => { return this.getSvg(m, overlay, settings) })]).subscribe(([background, ...gameBoards]) => {
					gameBoards.forEach(o => {
						o.background2 = background;
					});

					level.gameBoards.push(...gameBoards);
					level.showConsequenceMaps = true;
					this.productionTypes.value.forEach(c =>
						c.consequenceMaps = [...gameBoards.filter(c => c.gameBoardType == GameBoardType.ConsequenceMap)]);

					this.selectedFields.value.forEach(o => o.updateScore());

					this.currentLevel.next(level);
					this.selectedFields.next(this.selectedFields.value);
					this.loading(false);
				});
		}
	}

	getSvg = (m: any, overlay: GameBoard, settings: Settings) => this.tiffService.getSvgGameBoard(m.id, m.urlToData, m.gameBoardType, m.gradient, overlay, settings.minValue, settings.maxValue);

	initialiseSVGMode() {
		let level = new Level();
		const settings = this.settings.value;
		this.levels.push(level);
		this.loading();

		settings.customColors.forEach((c) => {
			let customColor = new CustomColors(c.id);
			c.colors.forEach((c) => {
				customColor.set(c.number, c.color);
			});
			this.customColors.push(customColor);
		});

		const drawingMap = settings.maps.find(o => o.gameBoardType == GameBoardType.DrawingMap)!;
		const backgroundMap = settings.maps.find(o => o.gameBoardType == GameBoardType.BackgroundMap)!;
		const otherMaps = settings.maps.filter(m => m.gameBoardType == GameBoardType.SuitabilityMap);

		this.tiffService.getOverlayGameBoard(drawingMap.id, drawingMap.urlToData, GameBoardType.DrawingMap).pipe(
			switchMap(overlay => {
				level.gameBoards.push(overlay);
				return combineLatest(
					[this.tiffService.getSvgBackground(backgroundMap.urlToData, settings.minValue, settings.maxValue, this.customColors.find(o => o.id == backgroundMap.customColorId)!),
					...otherMaps.map(m => { return this.getSvg(m, overlay, settings) }),]
				);
			})
		).subscribe(([background, ...gameBoards]) => {

			gameBoards.forEach(o => {
				o.background2 = background;
			});

			for (let i = 0; i < settings.productionTypes.length; i++) {
				const current = settings.productionTypes[i];
				const gameBoard = gameBoards.find(g => g.id == otherMaps.find(m => m.productionTypes.includes(current.id))!.id)!;
				const productionType = new ProductionType(current.id, current.fieldColor, gameBoard, current.urlToIcon, current.maxElements);
				this.productionTypes.value.push(productionType);
			}

			setTimeout(() => {
				this.selectedProductionType.next(this.productionTypes.value[0]);
			});

			level.gameBoards.push(...gameBoards);
			level.levelNumber = 1;

			this.currentLevel.next(level);
			this.focusedGameBoard.next(gameBoards.find(o => o.gameBoardType == GameBoardType.DrawingMap)!);
			this.loading(false);
		});

	}

	getGridGameBoard = (m: any) => this.tiffService.getGridGameBoard(m.id, m.urlToData, m.gradient, m.gameBoardType);

	initialiseGridMode() {
		let level = new Level();
		this.levels.push(level);
		this.loading();


		const settings = this.settings.value;
		const maps = settings.maps.filter(m => m.gameBoardType == GameBoardType.SuitabilityMap);

		combineLatest([
			...maps.map(m => this.getGridGameBoard(m))
		]).subscribe((gameBoards) => {
			level.gameBoards.push(...gameBoards);
			level.levelNumber = 1;

			settings.productionTypes.forEach((p) => {
				const gameBoard = gameBoards.find(g => g.id == maps.find(m => m.productionTypes.includes(p.id))!.id)!;
				this.productionTypes.value.push(new ProductionType(p.id, p.fieldColor, gameBoard, p.urlToIcon, p.maxElements));
			});

			this.productionTypes.next(this.productionTypes.value);
			setTimeout(() => {
				this.selectedProductionType.next(this.productionTypes.value[0]);
			});

			this.currentLevel.next(level);
			this.focusedGameBoard.next(gameBoards[0]);
			this.loading(false);
		});

	}

	getPercentageSelectedFields() {
		const selectedFields = this.selectedFields.value!.map(c => c.fields[0].id)
		const notSelected = this.focusedGameBoard.value?.fields.filter(o => o.editable && !selectedFields.includes(o.id)!).map(i => new SelectedField([{ id: i.id, side: HighlightSide.ALLSIDES } as HighlightField], i.productionType!))!;
		this.notSelectedFields.next(notSelected);
		return this.selectedFields.value.length / this.focusedGameBoard.value?.fields.filter(o => o.editable).length!;
	}

	openHelp(close = false) { this.helpWindow.next(!close); }

	loading(show = true) {
		if (show) {
			this.loadingIndicator.value.push(true);
		} else {
			this.loadingIndicator.value.pop();
		}
		this.loadingIndicator.next(this.loadingIndicator.value);
	}


	resetGame() {
		this.currentLevel.next(null);
		this.highlightFields.next([]);
		this.selectedFields.next([]);
		this.currentlySelectedField.next(null);
		this.productionTypes.next([]);
		this.selectedProductionType.next(null);
		this.focusedGameBoard.next(null);
		this.levels = [];
	}

	loadSettings(data: any) {
		this.resetGame();
		this.settings.next(new Settings(this.translateService, data));
	}

	private canFieldBePlaced(associatedFields: HighlightField[] = []) {
		if (this.selectedProductionType.value?.maxElements != 0 && this.selectedProductionType.value?.maxElements == this.selectedFields.value.filter(o => o.productionType == this.selectedProductionType.value).length) return false;
		return !(this.selectedFields.value.some(o => o.fields.some(p => associatedFields.some(q => q.id == p.id))));
	}

	private getAssociatedFields(id: number): HighlightField[] {
		let elementSize = this.settings.value.elementSize;
		if (elementSize == 1) {
			return [{ id, side: HighlightSide.ALLSIDES }];
		}

		let ids: HighlightField[] = [];

		let columns = this.settings.value.gameBoardColumns;
		if (columns - (id % columns) < elementSize) {
			id = id - (id % columns) + columns - elementSize;
		}

		let rows = this.settings.value.gameBoardRows;
		if (id >= (columns * rows - (elementSize - 1) * columns)) {
			id = (columns * (rows - elementSize) + (id % columns));
		}

		for (let i = id; i < (id + elementSize); i++) {
			let sidesX: HighlightSide[] = [];
			if (i == id) sidesX.push(HighlightSide.LEFT);
			if (i == id + elementSize - 1) sidesX.push(HighlightSide.RIGHT);
			for (let j = 0; j < elementSize; j++) {
				let sidesY = [...sidesX];
				if (j == 0) sidesY.push(HighlightSide.TOP);
				if (j == elementSize - 1) sidesY.push(HighlightSide.BOTTOM);
				ids.push({ id: i + (j * columns), side: this.getSide(sidesY) });
			}
		}

		return ids;
	}

	private getSide(sides: HighlightSide[]) {
		if (sides.some(o => o == HighlightSide.TOP)) {
			if (sides.some(o => o == HighlightSide.LEFT)) return HighlightSide.TOPLEFT;
			if (sides.some(o => o == HighlightSide.RIGHT)) return HighlightSide.TOPRIGHT;
			return HighlightSide.TOP;
		}

		if (sides.some(o => o == HighlightSide.BOTTOM)) {
			if (sides.some(o => o == HighlightSide.LEFT)) return HighlightSide.BOTTOMLEFT;
			if (sides.some(o => o == HighlightSide.RIGHT)) return HighlightSide.BOTTOMRIGHT;
			return HighlightSide.BOTTOM;
		}

		if (sides.length == 0) return HighlightSide.NONE;

		return sides[0];
	}
}
