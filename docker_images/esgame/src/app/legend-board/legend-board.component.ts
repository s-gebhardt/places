import { ChangeDetectionStrategy, Component, HostBinding, Input } from '@angular/core';
import { LegendElement, Legend } from '../shared/models/legend';

@Component({
	selector: 'tro-legend-board',
	templateUrl: './legend-board.component.html',
	styleUrls: ['./legend-board.component.scss'],
	changeDetection: ChangeDetectionStrategy.OnPush
})
export class LegendBoardComponent {
	legendElements: LegendElement[];
	isNegative = false;
	gradient: string = ""


	@HostBinding('class.is-small') @Input() isSmall: boolean = false;
	@HostBinding('class.is-gradient') @Input() isGradient: boolean = false;

	@Input()
	set legendData(data: Legend) {
		if (data) {
			this.legendElements = data.elements.sort((a, b) => a.forValue - b.forValue);
			this.isNegative = data.isNegative;
			this.isGradient = data.isGradient;
			if (data.isGradient)
				this.gradient = `linear-gradient(90deg, #${this.legendElements[0].color}, #${this.legendElements[1].color})`
			else
				this.legendElements = this.legendElements.filter(o => o.forValue != 0)
		}
	}
}
