import { ChangeDetectionStrategy, ChangeDetectorRef, Component } from '@angular/core';
import { GameService } from '../services/game.service';

@Component({
	selector: 'tro-score-indicator',
	templateUrl: './score-indicator.component.html',
	styleUrls: ['./score-indicator.component.scss'],
	changeDetection: ChangeDetectionStrategy.OnPush
})
export class ScoreIndicatorComponent {
	score: number | null = null;

	constructor(private gameService: GameService, private cdRef: ChangeDetectorRef) {
		this.gameService.currentlySelectedFieldObs.subscribe(o => {
			if (o) {
				this.score = o.scores.reduce((a, b) => a + b.score, 0);
			} else {
				this.score = null;
			}
			this.cdRef.markForCheck();
		});
	}
}
