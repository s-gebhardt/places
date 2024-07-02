import { GameService } from "src/app/services/game.service";
import { Field, HighlightSide } from "../shared/models/field";
import { ProductionType } from "../shared/models/production-type";
import { ChangeDetectorRef, Component, ElementRef, HostBinding, Input, OnDestroy, Renderer2 } from '@angular/core';

@Component({
	template: '',
})
export abstract class FieldBaseComponent implements OnDestroy {
	@HostBinding('class.--is-highlighted') public isHighlighted = false;
	@HostBinding('class.--is-assigned') public isAssigned = false;
	@HostBinding('class.--missing-selection') public isMissingSelection = false;
	@HostBinding('class.--is-editable') public isEditable = false;
	protected _field: Field;
	private _listeners: (() => void)[] = [];
	private _clickable = false;

	abstract shouldSelect(e: MouseEvent): boolean;
	abstract shouldDeselect(e: MouseEvent): boolean;

	constructor(protected gameService: GameService, protected renderer: Renderer2, protected elementRef: ElementRef, protected cdRef: ChangeDetectorRef) { }

	@Input() set field(field: Field) {
		this._field = field;
		this.isEditable = field.editable;
		this.setColor();
	}

	@Input() set clickable(clickable: any) {
		if (clickable === false) {
			this._clickable = false;
			this.removeListeners();
		} else {
			this._clickable = true;
			this.addListeners();
		}
	}

	get clickable() { return this._clickable; }

	get field(): Field {
		return this._field;
	}

	addClickListener() {
		this._listeners.push(this.renderer.listen(this.elementRef.nativeElement, 'mousedown', () => {
			if (this.field.assigned) this.gameService.deselectField(this.field.id);
			else this.gameService.selectField(this.field.id);
		}));
	}

	addHoverListener() {
		//if (this._field.editable)
			this._listeners.push(this.renderer.listen(this.elementRef.nativeElement, 'mouseenter', (e: MouseEvent) => {
				if(this.shouldSelect(e)) {
					this.gameService.selectField(this._field.id)
				} else if(this.shouldDeselect(e))
					this.gameService.deselectField(this._field.id);
				else
					this.gameService.highlightOnOtherFields(this._field.id);
			}));
		//else
			// this._listeners.push(this.renderer.listen(this.elementRef.nativeElement, 'mouseenter', () => {
			// 	this.gameService.removeHighlight();
			// }));
	}

	addListeners() {
		this.addClickListener();
		this.addHoverListener();
	}

	removeListeners() {
		this._listeners.forEach(fn => fn());
		this._listeners = [];
	}

	abstract setColor(): void;

	highlight(side: HighlightSide) {
		if (this.field.editable) {
			this.isHighlighted = true;
			this.cdRef.markForCheck();
		}
	}

	removeHighlight() {
		this.isHighlighted = false;
		this.cdRef.markForCheck();
	}

	addMissingHighlight() {
		this.isMissingSelection = true;
		this.cdRef.markForCheck();
	}

	removeMissingHighlight() {
		this.isMissingSelection = false;
		this.cdRef.markForCheck();
	}

	abstract assign(productionType: ProductionType, side: HighlightSide): void;

	abstract unassign(): void;

	ngOnDestroy(): void {
		this._listeners.forEach(fn => fn());
	}
}
