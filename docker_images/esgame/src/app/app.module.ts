import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { GridFieldComponent } from './field/grid-field/grid-field.component';
import { ProductionTypeButtonComponent } from './product-type-button/production-type-button.component';
import { ScoreBoardComponent } from './score-board/score-board.component';
import { LegendBoardComponent } from './legend-board/legend-board.component';
import { ButtonDirective } from './shared/button.directive';
import { HelpComponent } from './help/help.component';
import { ScoreIndicatorComponent } from './score-indicator/score-indicator.component';
import { MatSelectModule } from '@angular/material/select';
import { MatInputModule } from '@angular/material/input';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatButtonModule } from '@angular/material/button';
import { MatStepperModule } from '@angular/material/stepper';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatSliderModule } from '@angular/material/slider';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { MissingTranslationHandler, MissingTranslationHandlerParams, TranslateLoader, TranslateModule } from '@ngx-translate/core';
import { TranslateHttpLoader } from '@ngx-translate/http-loader';
import { HttpClientModule, HttpClient } from '@angular/common/http';
import { ConfiguratorComponent } from './configurator/configurator.component';
import { SvgGameBoardComponent } from './game-board/svg-game-board/svg-game-board.component';
import { GridGameBoardComponent } from './game-board/grid-game-board/grid-game-board.component';
import { SvgFieldComponent } from './field/svg-field/svg-field.component';
import { GridLevelComponent } from './level/grid-level/grid-level.component';
import { SvgLevelComponent } from './level/svg-level/svg-level.component';
import { LoadingIndicatorComponent } from './loading-indicator/loading-indicator.component';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { LevelIndicatorComponent } from './level-indicator/level-indicator.component';
import { ImportConfigComponent } from './import-config/import-config.component';
import { StartComponent } from './start/start.component';

export function HttpLoaderFactory(http: HttpClient) {
	return new TranslateHttpLoader(http);
}

export function createTranslateLoader(http: HttpClient) {
	return new TranslateHttpLoader(http, './assets/i18n/', '.json');
}

export class MyMissingTranslationHandler implements MissingTranslationHandler {
	handle(params: MissingTranslationHandlerParams): any {
	  return params.key;
	}
  }

@NgModule({
	declarations: [
		AppComponent,
		GridFieldComponent,
		ProductionTypeButtonComponent,
		ScoreBoardComponent,
		LegendBoardComponent,
		ButtonDirective,
		HelpComponent,
		ScoreIndicatorComponent,
		ConfiguratorComponent,
		SvgFieldComponent,
		SvgGameBoardComponent,
		GridGameBoardComponent,
		GridLevelComponent,
		SvgLevelComponent,
		LoadingIndicatorComponent,
		LevelIndicatorComponent,
		ImportConfigComponent,
  		StartComponent,
	],
	imports: [
		BrowserModule,
		BrowserAnimationsModule,
		AppRoutingModule,
		HttpClientModule,
		MatSelectModule,
		MatInputModule,
		MatIconModule,
		MatDividerModule,
		MatButtonModule,
		MatSliderModule,
		MatFormFieldModule,
		MatProgressSpinnerModule,
		MatCheckboxModule,
		FormsModule,
		ReactiveFormsModule,
		MatStepperModule,
		TranslateModule.forRoot({
			defaultLanguage: 'de',
			missingTranslationHandler: {
				provide: MissingTranslationHandler, useClass: MyMissingTranslationHandler
			},
			loader: {
				provide: TranslateLoader,
				useFactory: createTranslateLoader,
				deps: [HttpClient]
			},
			extend: true
		})
	],
	providers: [],
	bootstrap: [AppComponent]
})
export class AppModule { }

