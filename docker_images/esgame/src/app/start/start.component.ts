import { Component } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { GameService } from '../services/game.service';
import { MatSelectChange } from '@angular/material/select';
import { Router } from '@angular/router';

@Component({
  selector: 'tro-start',
  templateUrl: './start.component.html',
  styleUrls: ['./start.component.scss']
})
export class StartComponent {
	languages: string[];
	currentLanguage: string;

	constructor(
		private translate: TranslateService,
		private gameService: GameService,
		private router: Router
	) {
		this.gameService.resetGame();
		this.languages = translate.getLangs();
		this.currentLanguage = translate.currentLang;
	}

	changeLanguage(event: MatSelectChange) {
		this.translate.use(event.value);
	}

	loadDynamic() {
		this.router.navigate(['dynamic-game'])
	}

	loadStatic() {
		this.router.navigate(['static-game'])
	}
}
