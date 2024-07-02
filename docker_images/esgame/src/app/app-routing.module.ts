import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { ConfiguratorComponent } from './configurator/configurator.component';
import { GridLevelComponent } from './level/grid-level/grid-level.component';
import { SvgLevelComponent } from './level/svg-level/svg-level.component';
import { StartComponent } from './start/start.component';

const routes: Routes = [
	{
		path: '',
		component: StartComponent
	},
	{
		path: 'static-game',
		component: GridLevelComponent
	}, 
	{
		path: 'dynamic-game',
		component: SvgLevelComponent
	}, 
	{
		path: 'configurator',
		component: ConfiguratorComponent
	},
];

@NgModule({
	imports: [RouterModule.forRoot(routes, { useHash: true })],
	exports: [RouterModule]
})
export class AppRoutingModule { }
