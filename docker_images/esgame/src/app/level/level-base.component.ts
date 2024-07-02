import { ChangeDetectionStrategy, Component } from '@angular/core';
import { GameService } from '../services/game.service';
import { GameBoardClickMode } from '../shared/models/game-board';
import { ProductionType } from '../shared/models/production-type';
import { combineLatest, filter, map, tap } from 'rxjs';
import { GameBoardType } from '../shared/models/game-board-type';

@Component({
  template: '',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export abstract class LevelBaseComponent {
	readOnly = false;
	level = this.gameService.currentLevelObs.pipe(tap(o => {
		this.readOnly = o?.isReadOnly ?? false;
	}));
	selectedProductionType = this.gameService.selectedProductionTypeObs;
	focusedGameBoard = this.gameService.focusedGameBoardObs.pipe(filter(o => o != null));
	leftGameBoards = this.gameService.currentLevelObs.pipe(
		map(o => o?.gameBoards),
		map(o => o?.filter(p => p.gameBoardType == GameBoardType.SuitabilityMap)),
	);
	rightGameBoards = combineLatest([this.level, this.selectedProductionType]).pipe(
		map(([o, p]) => {
			if (o?.showConsequenceMaps) return p?.consequenceMaps;
			else return [];
		}));
	productionTypes: ProductionType[];
	clickMode = GameBoardClickMode;

	protected constructor(protected gameService: GameService) {
		this.gameService.productionTypesObs.subscribe(productionTypes => {
			this.productionTypes = productionTypes;
		});

		this.gameService.selectedProductionTypeObs.subscribe(productionType => {
			if (productionType) this.gameService.selectGameBoard(productionType.suitabilityMap);
		})
	}

	nextLevel() {
		this.gameService.goToNextLevel();
	}

	prevLevel() {
		this.gameService.goToPreviousLevel();
	}

	openHelp() {
		this.gameService.openHelp();
	}
}
