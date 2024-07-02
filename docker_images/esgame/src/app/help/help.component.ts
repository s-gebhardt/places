import { ChangeDetectionStrategy, ChangeDetectorRef, Component } from '@angular/core';
import { GameService } from '../services/game.service';
import { map } from 'rxjs';

@Component({
  selector: 'tro-help',
  templateUrl: './help.component.html',
  styleUrls: ['./help.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class HelpComponent {
	isOpen = false;
	helpText = 'basicInstructions';
	imageUrl = this.gameService.settingsObs.pipe(map(o => o.basicInstructionsImageUrl));

	constructor(
		private gameService: GameService,
		private cdRef: ChangeDetectorRef,
	) {
		this.gameService.helpWindowObs.subscribe(o => {
			this.isOpen = o;
			this.cdRef.markForCheck();
		});

		this.gameService.currentLevelObs.subscribe(o => {
			if (!o || o.levelNumber == 1) {
				this.helpText = 'basic_instructions';
				this.imageUrl = this.gameService.settingsObs.pipe(map(o => o.basicInstructionsImageUrl));
			} else {
				this.helpText = 'advanced_instructions';
				this.imageUrl = this.gameService.settingsObs.pipe(map(o => o.advancedInstructionsImageUrl));
			}
			this.cdRef.markForCheck();
		});
	}

	onClose() {
		this.gameService.openHelp(true);
	}
}
