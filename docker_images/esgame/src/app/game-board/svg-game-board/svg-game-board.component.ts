import { AfterViewInit, ChangeDetectionStrategy, ChangeDetectorRef, Component, ElementRef, Input, QueryList, Renderer2, ViewChildren } from '@angular/core';
import { GameBoardBaseComponent } from '../game-board-base.component';
import { SvgFieldComponent } from 'src/app/field/svg-field/svg-field.component';
import { GameService } from 'src/app/services/game.service';
import { GameBoardType } from 'src/app/shared/models/game-board-type';
import { GameBoardClickMode } from 'src/app/shared/models/game-board';

@Component({
	selector: 'tro-svg-game-board',
	templateUrl: './svg-game-board.component.html',
	styleUrls: ['./svg-game-board.component.scss'],
	changeDetection: ChangeDetectionStrategy.OnPush
})
export class SvgGameBoardComponent extends GameBoardBaseComponent implements AfterViewInit {
	@ViewChildren(SvgFieldComponent) svgFieldComponents: QueryList<SvgFieldComponent>;
	background: string = "";
	background2: string = "";
	mapType : GameBoardType = GameBoardType.DrawingMap;
	consequenceType = GameBoardType.ConsequenceMap;
	private _showHideListeners: (() => void)[] = [];

	constructor(gameService: GameService, renderer: Renderer2, elementRef: ElementRef, cdRef: ChangeDetectorRef) {
		super(gameService, renderer, elementRef, cdRef);
		this._sink.sink = this.gameService.highlightFieldObs.subscribe(fieldNumbers => {
			this._highlightedFields.forEach(o => this.svgFieldComponents?.find(s => s.field.id == o.id)?.removeHighlight());
			this._highlightedFields = fieldNumbers;

			if (fieldNumbers.length > 0) {
				fieldNumbers.forEach(fieldNumber => {
					this.svgFieldComponents.find(s => s.field.id == fieldNumber.id)?.highlight(fieldNumber.side);
				});
			}
			this.cdRef.markForCheck();
		});

		gameService.notSelectedFieldsObs.subscribe(_ => {
			if (this.svgFieldComponents) {
				// TODO: eventually add again
				// fields.forEach(field => this.svgFieldComponents.find(o => o.field.id == field.fields[0].id)?.addMissingHighlight());
				// setTimeout(() => fields.forEach(field => this.svgFieldComponents.find(o => o.field.id == field.fields[0].id)?.removeMissingHighlight()), 3000);
			}
		});
	}

	displayPatterns = 'inline';
	addShowHideListeners() {
		if (this.clickMode != GameBoardClickMode.SelectBoard || this._boardData.gameBoardType == this.consequenceType || this.readOnly) {
			this._showHideListeners.forEach(o => o());
			this._showHideListeners = [];
			return;
		}
		this._showHideListeners.push(this.renderer.listen(this.elementRef.nativeElement, 'mouseenter', () => {
			this.displayPatterns = 'none';
			this.cdRef.markForCheck();
		}));
		this._showHideListeners.push(this.renderer.listen(this.elementRef.nativeElement, 'mouseleave', () => {
			this.displayPatterns = 'inline';
			this.cdRef.markForCheck();
		}));
	}

	ngAfterViewInit() {
		this._sink.sink = this.gameService.selectedFieldsObs.subscribe(fields => {
			this._selectedFields = fields;
			setTimeout(() => this.drawSelectedFields());
		});

		this._sink.sink = this.svgFieldComponents.changes.subscribe(_ => {
			setTimeout(() => this.drawSelectedFields());
		});
	}

	protected drawSelectedFields() {
		if (this.fields && this._selectedFields && this.svgFieldComponents) {
			this.fields.forEach(field => this.svgFieldComponents.find(o => o.field.id == field.id)?.unassign());
			this._selectedFields.forEach(field => {
				field.fields.forEach(highlightField => {
					this.svgFieldComponents.find(o => o.field.id == highlightField.id)?.assign(field.productionType, highlightField.side);
				});
			});
			this.cdRef.markForCheck();
		}
	}

	override afterBoardDataSet(): void { 
        this.mapType = this._boardData.gameBoardType;
        this.background = `url("${this._boardData.background}")`;
        this.background2 = `url("${this._boardData.background2}")`;
        this.addShowHideListeners();
    }

	@Input() override set readOnly(value: boolean) {
		this._readOnly = value !== false;
		this.addShowHideListeners();
	}

	override get readOnly() {
		return this._readOnly; // Keep that because otherwise it doesn't work since we're overriding the setter
	}

	getStrokeOpacity() {
		if (this.boardData?.gameBoardType == GameBoardType.ConsequenceMap) {
			return 0.5;
		}
		return 1;
	}

	getStrokeWidth() {
		if (this.boardData?.gameBoardType == GameBoardType.ConsequenceMap) {
			return 20;
		}

		return 8;
	}
}
