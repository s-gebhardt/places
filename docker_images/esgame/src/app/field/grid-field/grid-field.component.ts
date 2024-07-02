import { ChangeDetectionStrategy, ChangeDetectorRef, Component, ElementRef, HostBinding, Input, Renderer2 } from '@angular/core';
import { SubSink } from 'subsink';
import { FieldBaseComponent } from '../field-base.component';
import { HighlightSide } from 'src/app/shared/models/field';
import { GameService } from 'src/app/services/game.service';
import { ProductionType } from 'src/app/shared/models/production-type';

@Component({
	selector: 'tro-field',
	templateUrl: './grid-field.component.html',
	styleUrls: ['./grid-field.component.scss'],
	changeDetection: ChangeDetectionStrategy.OnPush,
})
export class GridFieldComponent extends FieldBaseComponent {
	override shouldSelect(e: MouseEvent): boolean {
		return false;
	}
	override shouldDeselect(e: MouseEvent): boolean {
		return false;
	}
	private _imageMode = false;
	private _sink = new SubSink();

	@Input() set imageMode(mode: any) {
		this._imageMode = mode !== false;
	}

	get imageMode() { return this._imageMode; }

	private _size: number = 10;

	@HostBinding('style.width') private fieldWidth: string;
	@HostBinding('style.height') private fieldHeight: string;
	@HostBinding('style.background-color') private backgroundColor: string;
	@HostBinding('class') highlightSide = HighlightSide.NONE;
	@HostBinding('class.--has-image') showProductionImage = false;

	imageSize = 0;
	elementSize: number;

	@HostBinding('style.--highlight-color')
	highlightColor = '';

	constructor(
		gameService: GameService,
		renderer: Renderer2,
		elementRef: ElementRef,
		cdRef: ChangeDetectorRef
	) {
		super(gameService, renderer, elementRef, cdRef);
		this._sink.sink = this.gameService.settingsObs.subscribe(settings => {
			this.elementSize = settings.elementSize;
			this.imageMode = settings.imageMode;
		});
		gameService.settingsObs.subscribe(settings => {
			this.highlightColor = settings.highlightColor;
		});
	}

	@Input() set size(size: number | null) {
		size = size ?? 10;
		this._size = size;
		this.fieldWidth = size + 'px';
		this.fieldHeight = size + 'px';
	}

	setColor() {
		if (this.field) {
			if (this.field.productionType && !this.imageMode) {
				this.backgroundColor = this.field.productionType.fieldColor;
			} else {
				this.backgroundColor = this.field.type.fieldColor;
			}
		}
	}

	override highlight(side: HighlightSide) {
		this.isHighlighted = true;
		this.highlightSide = side;
	}

	assign(productionType: ProductionType, side: HighlightSide) {
		this.field.assigned = this.isAssigned = true;
		this.field.productionType = productionType;
		this.highlightSide = side;
		if (!this.imageMode) {
			this.setColor();
		}
		this.gameService.removeHighlight();
		this.cdRef.markForCheck();
	}

	unassign() {
		this._field.assigned = this.isAssigned = false;
		this._field.productionType = null;
		this.showProductionImage = false;
		this.highlightSide = HighlightSide.NONE;
		if (!this.imageMode) {
			this.setColor();
		}
		this.cdRef.markForCheck();
	}

	showProductionTypeImage() {
		this.showProductionImage = true;
	}

	override ngOnDestroy(): void {
		super.ngOnDestroy();
		this._sink.unsubscribe();
	}
}
