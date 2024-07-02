import { ChangeDetectionStrategy, ChangeDetectorRef, Component, ElementRef, HostBinding, HostListener, Input, OnDestroy, Renderer2 } from '@angular/core';
import { GameService } from '../services/game.service';
import { Field, HighlightField, SelectedField } from '../shared/models/field';
import { GameBoard, GameBoardClickMode } from '../shared/models/game-board';
import { Settings } from '../shared/models/settings';
import { Legend } from '../shared/models/legend';
import { SubSink } from 'subsink';
import { ProductionType } from '../shared/models/production-type';

@Component({
	template: '',
	changeDetection: ChangeDetectionStrategy.OnPush
})
export abstract class GameBoardBaseComponent implements OnDestroy {
	protected _boardData: GameBoard;
	protected _hideLegend = false;
	protected _clickMode = GameBoardClickMode.SelectBoard;
	protected _selectedFields: SelectedField[] = [];
	protected _highlightedFields: HighlightField[] = [];
	protected _sink = new SubSink();
	protected _listeners: (() => void)[] = [];
	protected _readOnly = false;

	fields: Field[] = [];
	settings: Settings;
	legend: Legend | undefined;
	GameBoardClickMode = GameBoardClickMode;
	productionTypes: ProductionType[] = [];
	@Input() set clickMode(mode: GameBoardClickMode) {
		this._clickMode = mode;
		if (mode == GameBoardClickMode.SelectBoard) {
			this.addClickListener();
		}
	}

	get clickMode() { return this._clickMode; }

	@HostBinding('style.grid-template-columns') fieldColumns: string;

	@Input()
	set boardData(data: GameBoard | undefined | null) {
		if (data) {
			this._boardData = data;
			this.fields = data.fields;
			this.legend = data.legend;
			this.afterBoardDataSet();
		}
	}

	abstract afterBoardDataSet(): void;

	get boardData() { return this._boardData; }

	@Input() set hideLegend(value: any) {
		this._hideLegend = value !== false;
	}

	get hideLegend() { return this._hideLegend; }

	@Input() set readOnly(value: any) {
		this._readOnly = value !== false;
	}

	get readOnly() { return this._readOnly; }

	protected constructor(
		protected gameService: GameService,
		protected renderer: Renderer2,
		protected elementRef: ElementRef,
		protected cdRef: ChangeDetectorRef
	) {
		this._sink.sink = this.gameService.settingsObs.subscribe(settings => {
			this.settings = settings;
		});
		gameService.productionTypesObs.subscribe(prodTypes => {
			this.productionTypes = prodTypes;
		});
	}

	@HostListener('mouseleave')
	onLeave() {
		this.gameService.removeHighlight();
	}

	@HostListener('contextmenu', ['$event'])
	preventContextMenu(event: Event) {
		event.preventDefault();
	}

	private addClickListener() {
		if (this.readOnly) return;
		this._listeners.push(this.renderer.listen(this.elementRef.nativeElement, 'click', () => {
			if (this._boardData) {
				this.gameService.selectGameBoard(this._boardData);
			}
		}));
	}

	protected abstract drawSelectedFields(): void;

	ngOnDestroy(): void {
		this._sink.unsubscribe();
		this._listeners.forEach(fn => fn());
	}
}
