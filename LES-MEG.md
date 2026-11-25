# Songify

Egen musikkapp uten innlogging. Kjører på Vercel, låtene ligger i Supabase.
Hver enhet/nettleser blir automatisk en egen bruker i bakgrunnen (anonym innlogging).

## Hvem ser hva
- **Felles låter**: låter admin har delt. Alle får dem i biblioteket sitt.
- **Egne låter**: det du laster opp selv er bare ditt, på den enheten.
- **Fjerne en felles låt** fjerner den bare hos deg. Den kan legges tilbake under «Felles».
- **Slette en egen låt** sletter den bare for deg.
- **Admin** ser alle brukeres låter under «Alle brukere», kan dele eller slutte å dele hvilken som helst låt, og kan slette alt.

## Bli admin
Trykk på rundingen øverst i appen, skriv inn admin-koden og trykk «Bli admin».
Koden står i `supabase.sql` (tabellen `ml_admin_code`). Må gjøres på hver enhet.

Bytte kode senere (Supabase SQL Editor):
```sql
update ml_admin_code set code = 'ny-hemmelig-kode' where id = 1;
```

## Filer
- `index.html` – selve appen
- `config.js` – koblingen til Supabase (Project URL og anon key)
- `supabase.sql` – kjøres i Supabase (SQL Editor)
- `manifest.json` og ikonene – gjør at appen kan legges på hjemskjermen

Maks filstørrelse per låt er 50 MB.
