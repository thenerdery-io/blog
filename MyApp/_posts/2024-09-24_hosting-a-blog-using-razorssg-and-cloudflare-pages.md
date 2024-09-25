---
title: Hosting a blog using Razor SSG and Cloudflare Pages
summary: How I host a modern blog for free using static HTML content and Cloudflare's global content delivery network
tags:
  - .net
  - GitHub
image: https://images.unsplash.com/photo-1618482914248-29272d021005?crop=entropy&fit=crop&h=1000&w=2000
author: Zachary Johnson
---

The number of choices for hosting a blog in 2024 is large enough to be downright paralyzing for mere mortals; between the multiple [hosting providers](https://blog.hubspot.com/website/best-blog-hosting-sites), numerous [content management systems](https://neilpatel.com/blog/best-content-management-systems/) and [frameworks](https://en.wikipedia.org/wiki/Web_framework), and an infinite number of themes and plugins there are literally millions of options.  While it's certainly possible to find turnkey blogging solutions—and realistically almost every blogger *should* do exactly that—I personally couldn't help but fall in love with the idea of static sites hosted for free on a global content delivery network.  From a reader perspective there's no better solution for performance, and for a webmaster there's no better solution in terms of security or cost.  It's really the best game in town if you're willing to do a bit of nerdery at the outset...

## Table of contents
1. [What is a static site (generator)](/posts/how-my-blog-works#what-is-a-static-site-generator)

### What is a static site (generator)?
A static site is essentially a collection of content that needs no server-side rendering: html files and all of the associated cascading style sheets, images, javascript files, etc. hosted on a standalone web server.  A static site *generator* is simply a tool for converting a dynamic site into one that is static.

Because a static site doesn't require server-side rendering and has no dependencies on a database or other complexities, the attack surface all but disappears and hosting charges range from free to just a few dollars per month—even for sites with high traffic!

Converting a dynamic site into one that is static may seem counterintuitive—why bother creating a dynamic site if the goal is a static site?—but let's not forget what's great about dynamic sites: code reuse and separating the developer experience from that of the content author.  Rather than developers copying & pasting site artifacts like headers/footers/navigation/layout into every single page and burdening content authors with the task of manipulating raw HTML without corrupting it, a dynamic site lets developers create and manage those artifacts a single time (and thus changes to those artifacts are simple) while content authors can interact with a much more friendly content management experience (ex: a markdown file or a fully-featured content management system like [Strapi](https://strapi.io/)).

The benefit of an SSG, then, is that it lets us have the best of both worlds:

- The developer interacts with reusable code via source control
- The content author interacts with a familiar content management system
- The operator manages as little infrastructure as humanly possible

For the purposes of a blog this is perfect unless and until the blogger wants to expose functionality like comments, forums and mailing lists.  But that's nerdery for a different blog post!

### What is a content delivery network (CDN)?
At its highest level a content delivery network is a collection of caching servers distributed across the globe.  When a client requests a web resource that sits behind a CDN, that client's traffic is directed to the geographically nearest "point of presence" (caching server) and the web resource is served from the CDN instead of traversing all the way to the underlying web server that hosts the uncached resource.  The benefits are myriad, but the biggest are:

- Blog readers experience the lowest possible latency regardless of where in the world they live because the content is cached in hundreds of sites
- The underlying web server doesn't need to worry very much about scaling out/up because it only handles uncached requests

When wrapped by a content delivery network (CDN) a static site can well and truly reach billions of users all over the world while sitting on a pair of "dumb" web hosts having just a single core and 512MB of RAM each.
### Key ingredients

- [Razor SSG Web Template](https://razor-ssg.web-templates.io/posts/razor-ssg) provides static site generation capabilities for websites written in the Razor framework.
- [GitHub](https://github.com) provides source control.
- [Cloudflare Pages](https://developers.cloudflare.com/pages/framework-guides/deploy-a-blazor-site/) provides free hosting on a global CDN and native integration with GitHub for CI/CD.


### Setting it all up

#### Program.cs

```csharp
services.AddAuthentication()
    .AddJwtBearer(options => {
        options.TokenValidationParameters = new()
        {
            ValidIssuer = config["JwtBearer:ValidIssuer"],
            ValidAudience = config["JwtBearer:ValidAudience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(config["JwtBearer:IssuerSigningKey"]!)),
            ValidateIssuerSigningKey = true,
        };
    })
    .AddIdentityCookies(options => options.DisableRedirectsForApis());
```

Then use the `JwtAuth()` method to enable and configure ServiceStack's support for ASP.NET Core JWT Identity Auth: 

#### Configure.Auth.cs

```csharp
public class ConfigureAuth : IHostingStartup
{
    public void Configure(IWebHostBuilder builder) => builder
        .ConfigureServices(services => {
            services.AddPlugin(new AuthFeature(IdentityAuth.For<ApplicationUser>(
                options => {
                    options.SessionFactory = () => new CustomUserSession();
                    options.CredentialsAuth();
                    options.JwtAuth(x => {
                        // Enable JWT Auth Features...
                    });
                })));
        });
}
```

### Enable in Swagger UI

Once configured we can enable JWT Auth in Swagger UI by installing **Swashbuckle.AspNetCore**:

:::copy
`<PackageReference Include="Swashbuckle.AspNetCore" Version="6.*" />`
:::

Then enable Open API, Swagger UI, ServiceStack's support for Swagger UI and the JWT Bearer Auth option:

```csharp
public class ConfigureOpenApi : IHostingStartup
{
    public void Configure(IWebHostBuilder builder) => builder
        .ConfigureServices((context, services) => {
            if (context.HostingEnvironment.IsDevelopment())
            {
                services.AddEndpointsApiExplorer();
                services.AddSwaggerGen();
                services.AddServiceStackSwagger();
                services.AddJwtAuth();
                //services.AddBasicAuth<Data.ApplicationUser>();
            
                services.AddTransient<IStartupFilter,StartupFilter>();
            }
        });

    public class StartupFilter : IStartupFilter
    {
        public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next)
            => app => {
                // Provided by Swashbuckle library
                app.UseSwagger();
                app.UseSwaggerUI();
                next(app);
            };
    }
}
```

This will enable the **Authorize** button in Swagger UI where you can authenticate with a JWT Token:

![](https://servicestack.net/img/posts/jwt-identity-auth/jwt-swagger-ui.png)

### JWT Auth in Built-in UIs

This also enables the **JWT** Auth Option in ServiceStack's built-in 
[API Explorer](https://docs.servicestack.net/api-explorer), 
[Locode](https://docs.servicestack.net/locode/) and 
[Admin UIs](https://docs.servicestack.net/admin-ui):

<img class="shadow p-1" src="https://servicestack.net/img/posts/jwt-identity-auth/jwt-api-explorer.png">

### Authenticating with JWT

JWT Identity Auth is a drop-in replacement for ServiceStack's JWT AuthProvider where Authenticating via Credentials
will convert the Authenticated User into a JWT Bearer Token returned in the **HttpOnly**, **Secure** `ss-tok` Cookie
that will be used to Authenticate the client:

```csharp
var client = new JsonApiClient(BaseUrl);
await client.SendAsync(new Authenticate {
    provider = "credentials",
    UserName = Username,
    Password = Password,
});

var bearerToken = client.GetTokenCookie(); // ss-tok Cookie
```

## JWT Refresh Tokens

Refresh Tokens can be used to allow users to request a new JWT Access Token when the current one expires.

To enable support for JWT Refresh Tokens your `IdentityUser` model should implement the `IRequireRefreshToken` interface
which will be used to store the 64 byte Base64 URL-safe `RefreshToken` and its `RefreshTokenExpiry` in its persisted properties:

```csharp
public class ApplicationUser : IdentityUser, IRequireRefreshToken
{
    public string? RefreshToken { get; set; }
    public DateTime? RefreshTokenExpiry { get; set; }
}
```

Now after successful authentication, the `RefreshToken` will also be returned in the `ss-reftok` Cookie:

```csharp
var refreshToken = client.GetRefreshTokenCookie(); // ss-reftok Cookie
```

### Transparent Server Auto Refresh of JWT Tokens

To be able to terminate a users access, Users need to revalidate their eligibility to verify they're still allowed access 
(e.g. deny Locked out users). This JWT revalidation pattern is implemented using Refresh Tokens which are used to request 
revalidation of their access and reissuing a new JWT Access Token which can be used to make authenticated requests until it expires.

As Cookies are used to return Bearer and Refresh Tokens ServiceStack is able to implement the revalidation logic on the 
server where it transparently validates Refresh Tokens, and if a User is eligible will reissue a new JWT Token Cookie that
replaces the expired Access Token Cookie.

Thanks to this behavior HTTP Clients will be able to Authenticate with just the Refresh Token, which will transparently
reissue a new JWT Access Token Cookie and then continue to perform the Authenticated Request:

```csharp
var client = new JsonApiClient(BaseUrl);
client.SetRefreshTokenCookie(RefreshToken);

var response = await client.SendAsync(new Secured { ... });
```

There's also opt-in sliding support for extending a User's RefreshToken after usage which allows Users to treat 
their Refresh Token like an API Key where it will continue extending whilst they're continuously using it to make API requests, 
otherwise expires if they stop. How long to extend the expiry of Refresh Tokens after usage can be configured with:

```csharp
options.JwtAuth(x => {
    // How long to extend the expiry of Refresh Tokens after usage (default None)
    x.ExtendRefreshTokenExpiryAfterUsage = TimeSpan.FromDays(90);
});
```

## Convert Session to Token Service

Another useful Service that's available is being able to Convert your current Authenticated Session into a Token
with the `ConvertSessionToToken` Service which can be enabled with:

```csharp
options.JwtAuth(x => {
    x.IncludeConvertSessionToTokenService = true;
});
```

This can be useful for when you want to Authenticate via an external OAuth Provider that you then want to convert into a stateless
JWT Token by calling the `ConvertSessionToToken` on the client, e.g:

#### .NET Clients

```csharp
await client.SendAsync(new ConvertSessionToToken());
```

#### TypeScript/JavaScript

```ts
fetch('/session-to-token', { method:'POST', credentials:'include' })
```

The default behavior of `ConvertSessionToToken` is to remove the Current Session from the Auth Server which will prevent 
access to protected Services using our previously Authenticated Session. If you still want to preserve your existing Session 
you can indicate this with:

```csharp
await client.SendAsync(new ConvertSessionToToken { 
    PreserveSession = true 
});
```

### JWT Options

Other configuration options available for Identity JWT Auth include:

```csharp
options.JwtAuth(x => {
    // How long should JWT Tokens be valid for. (default 14 days)
    x.ExpireTokensIn = TimeSpan.FromDays(14);
    
    // How long should JWT Refresh Tokens be valid for. (default 90 days)
    x.ExpireRefreshTokensIn = TimeSpan.FromDays(90);
    
    x.OnTokenCreated = (req, user, claims) => {
        // Customize which claims are included in the JWT Token
    };
    
    // Whether to invalidate Refresh Tokens on Logout (default true)
    x.InvalidateRefreshTokenOnLogout = true;
    
    // How long to extend the expiry of Refresh Tokens after usage (default None)
    x.ExtendRefreshTokenExpiryAfterUsage = null;
});
```
