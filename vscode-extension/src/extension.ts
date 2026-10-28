
import * as vscode from "vscode";

export function activate(context: vscode.ExtensionContext) {
  const command = vscode.commands.registerCommand(
    "bacus.createPackage",
    async () => {
      const name = await vscode.window.showInputBox({
        prompt: "Nombre del paquete Bacus"
      });

      if (!name) return;

      vscode.window.showInformationMessage(
        `Paquete seleccionado: ${name}`
      );
    }
  );

  context.subscriptions.push(command);
}

export function deactivate() {}
