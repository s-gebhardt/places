import { ChangeDetectionStrategy, ChangeDetectorRef, Component, Input, OnInit } from '@angular/core';
import { GameService } from '../services/game.service';
import { ScoreEntry, ScoreService } from '../services/score.service';
import { TranslateService } from '@ngx-translate/core';

@Component({
  selector: 'tro-score-board',
  templateUrl: './score-board.component.html',
  styleUrls: ['./score-board.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ScoreBoardComponent implements OnInit {
	private _isStatic = false;
	private _scores: ScoreEntry[] = [];
	totalScore: number = 0;
	@Input() set scores(value: ScoreEntry[] | undefined) {
		if (value) {
			this._scores = value;
			this.calculateTotalScore();
		}
	}
	get scores() {
		return this._scores;
	}

	get groupedScores() {
		const grouped =  this._scores?.reduce(
			(entryMap, e) => entryMap.set(this.translateService.instant("map_name_" + e.id) as string, [...entryMap.get(this.translateService.instant("map_name_" + e.id))||[], e]),
			new Map<string, ScoreEntry[]>()
		);

		return Array.from(grouped).map((a) => ({ name: a[0], score: a[1].reduce((a, b) => a + b.score, 0)}));
	}

	@Input() set isStatic(value: any) {
		this._isStatic = value !== false;
	}

	constructor(
		private gameService: GameService,
		private cdRef: ChangeDetectorRef,
		private scoreService: ScoreService,
		private translateService: TranslateService
	) {}

	ngOnInit() {
		if (!this._isStatic) {
			this.gameService.currentLevelObs.subscribe(level => {
				this._scores = this.scoreService.createEmptyScoreEntry(level);
				this.cdRef.markForCheck();
			});

			this.gameService.selectedFieldsObs.subscribe(fields => {
				this.scoreService.calculateScore(this._scores, fields);
				this.calculateTotalScore();
				this.cdRef.markForCheck();
			});
		}
	}

	private calculateTotalScore() {
		this.totalScore = this._scores.reduce((a, b) => a + b.score, 0);
	}
}
