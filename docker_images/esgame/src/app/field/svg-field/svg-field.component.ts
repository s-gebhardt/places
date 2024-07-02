import { ChangeDetectionStrategy, Component, HostBinding, Input, OnInit } from '@angular/core';
import { HighlightSide } from '../../shared/models/field';
import { ProductionType } from '../../shared/models/production-type';
import { FieldBaseComponent } from '../field-base.component';

@Component({
	selector: '[troSvgField]',
	template: '',
	styleUrls: ['./svg-field.component.scss'],
	changeDetection: ChangeDetectionStrategy.OnPush
})
export class SvgFieldComponent extends FieldBaseComponent implements OnInit {
	override shouldSelect(e: MouseEvent): boolean {
		return e.buttons == 1 || e.shiftKey
	}
	override shouldDeselect(e: MouseEvent): boolean {
		return e.buttons == 2 || e.ctrlKey
	}
	@HostBinding('style.fill') private fillColor: string;
	@HostBinding('style.stroke') private stroke: string;
	highlightColor: string;

	@HostBinding('class.show-stroke') @Input() showStroke: boolean = true;

	@Input() gameBoardId = '';

	@Input() hasOpacity = false;

	ngOnInit(): void {
		this.gameService.settingsObs.subscribe(o => {
			this.highlightColor = o.highlightColor;
		});
	}

	setColor(productionType: ProductionType | null = null) {
		if (!this._field) return;
		if (productionType && this.clickable) { 
            if (this.hasOpacity) { 
                this.fillColor = `${productionType.fieldColor + '7D'}`; 
            } else { 
                this.fillColor = `${productionType.fieldColor}`; 
            } 
        } else if(productionType) {
			this.fillColor = `url(#pattern_${productionType.id}_${this.gameBoardId})`;
		} else {
			this.fillColor = "";
		}
	}

	override highlight(side: HighlightSide): void {
		super.highlight(side);
		this.stroke = this.highlightColor;
	}

	override removeHighlight(): void {
		super.removeHighlight();
		this.stroke = '';
	}

	assign(productionType: ProductionType, side: HighlightSide) {
		if (!this.field.editable) return;
		this._field.assigned = this.isAssigned = true;
		this.setColor(productionType);
		this.gameService.removeHighlight();
	}

	unassign() {
		this._field.assigned = this.isAssigned = false;
		this._field.productionType = null;
		this.setColor();
	}

}
