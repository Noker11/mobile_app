# TodoList

Jednoduchá to-do list appka pre iOS napísaná vo SwiftUI.

## Funkcie

- Pridávanie úloh cez textové pole a menu tlačidlo (`...`)
- Zaškrtávanie úloh (klik na riadok alebo na krúžok)
- Mazanie úloh potiahnutím (swipe) alebo cez Edit režim
- Presúvanie poradia úloh v Edit režime
- Hromadné zmazanie všetkých zaškrtnutých úloh cez menu (`...` → "Odmazať zaškrtnuté úlohy")
- Dáta sa ukladajú lokálne do JSON súboru v Documents priečinku appky, takže úlohy prežijú reštart appky

## Požiadavky

- Xcode 16+
- iOS 17+ (deployment target)

## Spustenie

1. Otvor `TodoList.xcodeproj` v Xcode
2. Vyber iOS simulátor alebo zariadenie
3. Spusti appku (⌘R)

Alebo cez príkazový riadok:

```bash
xcodebuild -project TodoList.xcodeproj -scheme TodoList -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

## Štruktúra projektu

- `TodoList/TodoListApp.swift` – vstupný bod appky
- `TodoList/ContentView.swift` – hlavná obrazovka so zoznamom úloh
- `TodoList/TodoItem.swift` – model jednej úlohy
- `TodoList/TodoListStore.swift` – logika (pridanie, zaškrtnutie, mazanie, presúvanie) a perzistencia do JSON
