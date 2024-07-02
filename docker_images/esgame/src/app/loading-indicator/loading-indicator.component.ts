import { Component, HostBinding } from '@angular/core';
import { GameService } from '../services/game.service';

@Component({
  selector: 'tro-loading-indicator',
  templateUrl: './loading-indicator.component.html',
  styleUrls: ['./loading-indicator.component.scss']
})
export class LoadingIndicatorComponent {
	
	@HostBinding('class.show')
	show = false;

	constructor(private gameService: GameService) {
		this.gameService.loadingIndicatorObs.subscribe(show => {
			this.show = show.length > 0;
		});
	}
}
