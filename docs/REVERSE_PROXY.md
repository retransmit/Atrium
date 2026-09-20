# Behind a reverse proxy

Atrium talks to your services over ordinary HTTP. When something sits in
front of them and authenticates the request before it arrives, whether that
is Authelia, Cloudflare Access or an nginx Proxy Manager access list, the app
has to carry that credential too. Otherwise the proxy answers instead of the
service and every request comes back as a login page.

That is what **Settings > Network > Custom Headers** is for. This page covers
where to put the header, which name to use, how to configure the common
proxies, and what the dashboard is telling you when it turns yellow.

## Where headers go

Two scopes, both on that screen:

- **Global headers** are sent with every request to every instance in the
  profile. The right place when one proxy fronts your whole stack.
- **Per instance** headers are sent to that one instance only, and override a
  global header of the same name. Use these when only some services sit
  behind the proxy, or when one of them needs a different credential.

They merge in that order: global first, per instance on top. The service's
own authentication wins last. If you configure a header that the service
already uses to sign in, yours is replaced before the request leaves the
phone. The app warns about that while you are typing the name, but it is
worth understanding why, which is the next section.

## Choosing the header name

`Authorization` looks like the obvious choice and it is the one that breaks.

It fails in two separate ways:

- **It gets overwritten.** NZBGet, Transmission, rTorrent, Speedtest Tracker
  and Tracearr all send their own credentials in that header. For those
  instances your value never reaches the wire.
- **It gets rejected.** qBittorrent parses an `Authorization` header it did
  not issue and answers 401 instead of falling back to its session cookie. A
  proxy credential sent that way locks you out of a service that is otherwise
  perfectly reachable.

Use **`Proxy-Authorization`** instead. It is the header RFC 7235 reserves for
an intermediary, and nothing in the stack sets it or refuses it, so it is the
only name that survives every instance in a profile.

| Header | Verdict |
| --- | --- |
| `Proxy-Authorization` | Use this for proxy credentials. |
| `CF-Access-Client-Id`, `CF-Access-Client-Secret` | Safe, nothing touches them. |
| `Authorization` | Overwritten by five services, refused by qBittorrent. |
| `X-Api-Key` | Overwritten by every *arr. It is their own key header. |
| Anything else | Fine unless the app warns you about it. |

Whether your proxy *reads* `Proxy-Authorization` is a separate question, and
not every one does. See your proxy below.

For Basic credentials the value is the word `Basic`, a space, then
`username:password` encoded as base64:

```sh
printf 'user:pass' | base64
```

## Authelia

Authelia will read `Proxy-Authorization`, but not by default. Its authz
endpoints ship with `HeaderAuthorization` in their strategy list, so out of
the box `Authorization` is the only header it looks at. Add the proxy
strategy to the endpoint your proxy actually calls:

```yaml
server:
  endpoints:
    authz:
      forward-auth:        # or auth-request / ext-authz, whichever you use
        implementation: ForwardAuth
        authn_strategies:
          - name: HeaderProxyAuthorization
            schemes:
              - Basic
          - name: CookieSession
```

Two things that bite:

- **Keep `CookieSession` in the list.** Writing `authn_strategies` yourself
  replaces the defaults rather than adding to them, so leaving it out signs
  out every browser session going through that endpoint.
- **The rule has to be `one_factor`.** A header credential is a single factor
  by definition, so a `two_factor` rule denies it however correct the header
  is. Give the subdomains Atrium talks to their own `one_factor` rule, or
  narrow it to the users who need it.

The user in the header has to exist in Authelia's backend and be allowed by
the rule. It is the same identity as a browser login, just presented
differently.

## Cloudflare Access

Create a service token and add both of its headers globally:

```
CF-Access-Client-Id: <client id>.access
CF-Access-Client-Secret: <client secret>
```

Neither name collides with anything, so the global scope is safe for the
whole profile. The Access policy in front of your services needs a rule that
accepts that service token.

## nginx, nginx Proxy Manager, and basic auth generally

nginx's `auth_basic`, which is what an nginx Proxy Manager access list runs
on, reads `Authorization` and nothing else. It does not look at
`Proxy-Authorization` and cannot be configured to.

So on plain basic auth you are stuck with `Authorization` and the collisions
above. What works:

- Add the header **per instance** rather than globally, skipping the
  instances that spend `Authorization` on themselves.
- Leave qBittorrent out of it entirely. It will answer 401.
- Better: allow your own network in the access list so the app needs no
  credential at all, or put a real forward-auth in front instead of basic
  auth.

For any other proxy the question to answer is simply which of the two header
names it reads. An `auth_request` to Authelia reads whatever Authelia is
configured for; a plain basic-auth module almost always means
`Authorization`.

## Sub-paths

An instance served at `https://home.example.com/sonarr` works. Put the whole
URL, path included, in the instance's Local or External URL.

Artwork resolves its headers from the URL, and the longest matching instance
base wins, so two services under one hostname on different sub-paths each get
their own headers rather than the other one's.

## Posters and artwork

Artwork is the one part of the app that does not go through the normal HTTP
client. Posters, banners and backdrops are fetched by the image cache
directly. Since 1.6.1 they carry the same headers as everything else, worked
out from the image URL.

Two consequences worth knowing:

- Artwork served by **your** instances gets your headers. That is what makes
  posters appear behind a forward-auth proxy at all.
- Artwork served by **anyone else** gets nothing. Add-search results point at
  TMDB and Fanart.tv, and your proxy credentials have no business leaving
  your network.

## What the dashboard dot means

- **Online**: the service answered its own status endpoint and the
  credentials worked.
- **Warning**: the host answered, but not the way a healthy service should.
  Behind a proxy this usually means the proxy answered instead of the
  service.
- **Offline**: nothing answered at all.

Before 1.6.1 a forward-auth login page was reported as Online. The probe
followed the redirect like any client would, the portal returned a perfectly
healthy 200, and status alone could not tell that apart from a working
server. It is a Warning now. If services went yellow when you upgraded,
nothing broke; the app just stopped believing the login page.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Every service Warning right after upgrading | The proxy is intercepting everything. The header is missing, on the wrong scope, or under a name the proxy does not read. |
| qBittorrent 401s and nothing else does | It has an `Authorization` header configured. Move that credential to `Proxy-Authorization` or drop it for that instance. |
| Header is set and the proxy still rejects it | The proxy reads the other name. nginx basic auth reads `Authorization` only; Authelia needs `HeaderProxyAuthorization` turned on. |
| Authelia rejects a header you know is correct | The rule is `two_factor`. Header auth is one factor. |
| Works on Wi-Fi, fails away from home | Only the external URL goes through the proxy. Headers apply to both URLs, so the problem is the external URL or the proxy in front of it. |
| Posters blank while the rest of the service works | An app older than 1.6.1. |

## Self-signed certificates

Per instance, in its edit screen. Off by default, and worth leaving off for
anything reachable from the internet.
