import { ChangeDetectionStrategy, Component, HostBinding, HostListener, Input, OnInit } from '@angular/core';
import { ProductionType } from '../shared/models/production-type';
import { GameService } from '../services/game.service';

@Component({
	selector: 'tro-production-type-button',
	templateUrl: './production-type-button.component.html',
	styleUrls: ['./production-type-button.component.scss'],
	changeDetection: ChangeDetectionStrategy.OnPush
})
export class ProductionTypeButtonComponent implements OnInit {
	@Input() productionType: ProductionType;

	@HostBinding('class.--active') isActive = false;
	@HostBinding('class.--image-mode') isImageMode = false;
	backgroundColor = '';

	constructor(private gameService: GameService) {
	}

	ngOnInit(): void {
		this.gameService.settingsObs.subscribe(o => {
			this.isImageMode = o.imageMode;
			this.backgroundColor = this.productionType.fieldColor;
		});
		this.gameService.selectedProductionTypeObs.subscribe(o => {
			this.isActive = o == this.productionType;
		});
	}

	@HostListener('click')
	onClick() {
		this.gameService.setSelectedProductionType(this.productionType);
	}
}
