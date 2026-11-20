#import "SaoqiangWCAssets.h"
#import "SaoqiangWCAssetsInspector.h"
#import "SaoqiangWCAssetsThemePack.h"
#import <TargetConditionals.h>
#import <objc/runtime.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

// Global two-finger long-press target: opens the panel directly on the icon
// page from anywhere in WeChat. Forward-declared because the gesture target
// class is defined before the panel helpers that implement it.
static void SaoqiangWCAssetsPresentIconPage(void);
static void SaoqiangWCAssetsPresentThemePage(void);

// Embedded 256px transparent line-art logo (assets/logo-hand-in-box.png).
static NSString * const SaoqiangWCAssetsLogoBase64 =
    @"iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAYAAABccqhmAABEC0lEQVR42u19abQkV3HmdzOrXr33epe6JbW21o52IYlFCASYzQaDbVYbGBsPc8YrtgEz4+XM"
    @"mTln5vjf+Iw9NgbGYGNmbGMYGzCbWWQhsUhICKEFpBba1Wqp9/VtVZV550fEnRcdulmVmZVVlfXqxjl1uvt1d1VW5r1xI7744gsgWLBgwYIFCxYsWLBgwYIF"
    @"CxYsWLBgwYIFCxYsWLBgwYIFCxYsWLBgwYIFCxYsWLBgwYIFCxYsWLBgwYIFCxYsWLBgwYIFCxYsWLBgwYIFCzZ+iwv826MAngPgBwAOA2gAMABsuI3Bgo3F"
    @"It6D7vcR7+nLAeyp+sN+BOBNAJriw4y4gGk0M+D/NWENB6to/RmxL9flfYNGgQ+7GcB3AXTCyf//b7y8D0U3s/W8R9GHHqKv6TabsT6Wh5ECdAA8ACANDqDv"
    @"A0CBTeo8t/VEByFCCFZ2PdphYABLJU+taYkKTMbmdrlZ5Hk1BZ4STvZgg65BO6wctgWgyx9gOBIIi3V141vlVN3PZKifqnsHcT+lA7Hi92m4x8GGZUUwgC6A"
    @"RCzwsChP3LSR2sBu4zb4njUBzAKYERGB5fva4bztOP8/Fy1AvV+wYGNzAOHEP/Gkdps9EfelAWA9gDMAnAfgNH6dDGADgI0cSTV4g6e8+Y8B2AtgF4C7ANwD"
    @"4AC/Z8wvHVGEdCFYr6jeVu0AKss7JvjGRmrTGwCbAZwJ4khcBuAKAOcD2AYqxzRFFBCp+yV/7QBYBPAMgB+Cqi7fAvAwgAVV67Vh4werYk8GlHk1b7fiJTe7"
    @"FZvObfxtAC4AcC2AGwBcCWALgHkO8xvKE1uV19seOELKacEiiMzxbQBfBXAngEf438+I90wyKggIaUOw4ACQm1EFAdJFns07w2H98wG8FsB1AE7hzW57kKN8"
    @"ZUGTAQLKTZ0K7OUYpwX/COBLAJ4STskHNiJECcGCAxiMWgkR7j8HwFsBvIpD/I3CUSQZ6L3tQxayHgcEgQ3I092BhocA3ALgwwC+JtI4q9KJcPIHC1YyFWiI"
    @"zT3LG//LAPbxxkr41QWwwrl7R6D5HfXv0pwv+e+76nM64mddADsBvA/AJnHN8tfg4IMFK3H6N4QDmAHwG6AeiAXehG4Duk3Z5t/LjWwrfDln0OaXdAr7ALyf"
    @"r7MhogTjAS2DBQvWJxVyJ2iLX+8AgW769NUbX2/YQTd8mvGzVFQLlkGszKcAXC+uX/IHggMIFqygE3Ah9A2gtue2COnlhkwyHEAVJ37Wn93nOge0wr/+DYh7"
    @"EIsoJliwYCVr/OcB+AJvthURevc7tdMcG7rfK+nxPh2Vbrh04BCoTRucDjSnDIAOOEewSk5+B/r9kajDLw/hlK8yOnCO6fOgkqRrLjIiLairs22o0mmZDR57"
    @"cI/gEIKhDPgHAG8B8IQC3eriAGyPyOAIgA8IEHPW02E4KSd9lMMx9Pv74ASCFVpwMYjJ9zmB9td98zsH0Obffw/Apfyd1rETqHOrNFSkEqtKTKwo1FGBHo0Q"
    @"CRRkwE1zY0/Mm/3VAJ4nGHaTwLmXYiJXcQTTZOwirdEmsH20ESRzsascsK7UZOkqRKrXIrAgUa0gyFpslnALZhOA9wJ4YYZzNBOgBNMA9Sh8GdRJWJcmLeMR"
    @"rpSdlFac/Bv4WWzkX1tiw0uGY9Sj+SVsfAynHXitgn9t3vgv9PTzV7HxU0+DUdVRnDsxzwfwBgB/WhPpNuNxoLJ5aROAHaAuyksAnAPqrpzj618GsJ9xmR8D"
    @"eBTEfTgIAmnTPg47OIPgAHqGzinn/j8L4EKR/zfVok1LoszWI+xRdUQhHdUsgHcC+CSokzCuQTgseyZS3uAX8IZ/PoBrQBWMWdE6rZ2ncwYHADwO4EEAjwHY"
    @"DWqXfgxEjJLPNVhwAH03WwLgxQB+WtXXW2LjxCU2vRG/7gGJfWwDiYPYIUqSGY4CrgMBmhHn1OMWpEgBbOco60UAXsCn/ZzK73UOL//cBBGezuZn1gYpKD0K"
    @"4HZQ2/QPODowPdqvQ3QwZQ5An7puUSUcfv4Sb86OWIgSIzjCm+kIRwpne1p6fadyxIvyjzh83Qbgd0DNRXqBV+XgEs6jXwXgsxmtx6NQS4pEqL8JwMsAvBkE"
    @"VJ4EIiy5ez2jNr9MW3x6iNJRzwPYCtJj+El2BJ/hX5fFewY1KwSyj1ykji33dg4hF4Uiz7Ii3ryPI4IIxLjb24fl5xb+cQC/rD7/HADfFGh3OgROgAUpCW0T"
    @"Q1yGWRYzHoQ/5pD+OgAfBGkZ7OXT+SBIYXoRq92UspOyo0qxsiIgm6Ha/B5HODV4hlOBb7CjPQMnkoWiwBVA6PMXi7QJ4A95YS7zoloWC9IC+A5vJLdgNgL4"
    @"fh8H4H7+EEg7wIhTDgA+IhyAHZIDeALAa1REY4ac48uS3mnsOG/nFOggSNRkge9xW2ziFf7ZAjuG4/wz2YAlHYCkXjvHscLvf5AdwU4Af83phmZ7BgcwpSCg"
    @"LhVFAnHW4asLGT8GarttqA2PHmmA+/kh/r8yKohF9GGH+B23sPP56ggWuhEpj+Vw/FcBvI7TkSa/YhXiy81thbNqekqHWYQiqVAdq4jnlZyu/RWnQwsiGkhC"
    @"OjCdVQCjooL14mSQiyvmBfMj8W+7/O/ncp4g7qST/387CAGHB6galGQjndc8h8BaNmyYeb/lE/f9DNLNcOokB5+kqjKSKgfQFJs6KoDrQPRByHtyCYgifSaA"
    @"j3M00gjCqtPnALKkuubVQpJDPQ6wE5DO4Vw+XZGzPKcX2+tBCLgdYljuTsOtvAHbI3KqLwTw+yA25Tohf+6bnSC/v0tdZgqAor16AJoKZN0O4F18P/4MwJMi"
    @"oktCbjy9uv5goCryzOazipDicutXMSbQ6+R277OZF52r078CxDZsDZmk49KXLeKzhnk/E45q3sfObV7cV+spwWnG3gxHVq0B8AqtrzgrUrsmiGfwJgDv4eeX"
    @"hn6B6aICG88ibAF4I4CLPaGkFYtoJzuA1wD4j6AhH8jRwrqZQcNZzof/gENS20c1eJDoRkYAT4HKl8crKjWajB6EdSDptDfyd533dCJq2XOrxE7jAa/RV1Jt"
    @"qL+bAVVhuiCJ9a7nuwVgcAqIQK7DbAOoZpwoVFkLfNwH4CsgdDmPyIcWBzkm8txkCB2BSUYl4DaQuElUgVBopKTGXH5vQPX3e0GU3UXF3vOV8qqqeOjnlGb8"
    @"XFYI9vDmf6fAG3QzUcAApgQTaIj6vgaVXIjYBfHUL8Mq0SYu8Bkpn5Buo0YjcHBGPNvmgECjJPXoCCoFcDqAn+cQO1adfakH7ByGCpDtMw1HVwe2A/g3IErx"
    @"bep524ABTNcM9TgjjI5F7ViWq6ISzEOrQuZRpjpxRTV+TaRyp/tPAHiJCONjNTpNt/8Ou7xrMp5FJMqRTU7F3qHwAFScmgUHUGMHIENG3VRjPKBSkQVsegwa"
    @"iUbo4OIKSo3Wc/o7B3AKYxvbRDgd51TsqeI7pmrkmu0xck0yQN2U5heBypWaejxVWEA0ZSVA+b1dMwkywKCyKjO93meUEU6iphYN4ix9Q01vwCrqPy8wgWFr"
    @"86UqMrGebk3bo0fBvbaA+hPOzIjaggNYo2G/Wwxt0DjupCJCTl35DoMuaI3Yp6BKyJtATLvGCDn2bvO7CcqLOXsdpBOYEVHA5SD+QjStVYBoiqXAEqwO/liL"
    @"k3QT8d2qdCwtAL8OKotGYliJz2kMY/M/BOA/g0qPHxOfbT3zFRPPz93mnwHxNG7gCCaq0GkGB1DjbsBULKYHQCUiTPBEXeuhBIMjnOUKowHHL3grgF8Btfna"
    @"Hnmzrfi7uWf2CQAfBQ1J/Sus9v/7gL8sXEA6gWsAXCRA3qk6FKMpHPzhHEAMooU+qsp/1qNIY2v+DK3nWpex2tpcBXMy4c3y70HAX68qR1UbyQosowHqzvw7"
    @"nAhGmozqi+lRmpRzCc7iKGAU4GVwADUQBZGn5NOgllXfaWEniCFmPLnwYayKYlShOrwVxPY7U93HrsqhNWkHFTD8GiBxlfeCev6d1NkcTuzfyCoRGk+EF4kZ"
    @"CteBxGG6Q+7TCA6gZnYUwHdFqDzJQJDefE+DQDIzYNjvfn0OgGtBvH2jmIiRJw0xqgOw7OY/CuAvAPxbAHcIIBIcyic5tSAiz2HgWo+vBKkWmZrJqQcHMIQo"
    @"IFIb5ccgAQ3Tp3owKd8xZlxjZwXXL0/C8zn0n1UnqZ5I/BSAW0H04MNiA3Y8zsD2AR0fYLzhd/g5xaK0GYP6LVol+AMQ194AlQRfyL/aadoX0ZSRf6xHH+4h"
    @"kJikT0BzkkJBSYo5AJLhqvI9TwP1T+iKiWz82QvgdwH8FGhIyXtBcwqOCjqu1PQzPdD+Ngjl/xRWqdsyQpsD8HIQGJkU7F60SimoAWoKO7eP2AtCL8Da4QO4"
    @"738ApNP3erFA4wlMB4wK/x8UufKg96zFGEDkUSGWoiMPAriRN/wxEN/+Jg6vXwPgpSDuQC+SlnzvOX5GVs1XSEEkpHcUfE5SJNSlEk1OAU8BUYTvEgpHaXAA"
    @"WFNSYFmn+/dAnIDnTHD9V3a/3c+ncXNALoARLb8bhENpePJ+8CY6hZ1qDKqvHwPwaY4ELuZ8+6WgUWwn9ThtmyDR1kdBJb8lrNbuXwESXD21QI+GURRpXR2a"
    @"A3VPzqGaFurgAGp66usSU5NPrvtB9eDuhOkk6Pl5C6AuN61fWMVMP9sDYYfQ7HdSasfFSXoQpFZ8K0in4F0Afg+kmaBnKbhrvxTAH3OKtsBO6HSQAEmrZIel"
    @"rvhItaLN7GSmhgg0zaPBrBg4cRAkJ/0yEMqdiBCxzjiAVfm0BfW8f2tABN43RCP1yHfBo7D0cwA+L+TTrScEf4ZD7ePKARjP554K0hzIAjwH6ZaUUUDMkU4D"
    @"oQowVdblB/4voBrzjJClrjsIKIVAOxwmfxoEbFaRw7qNuSJIRTajVu6cxEs5dG94hEjc/2txKrBN5Nt5Spt2wPFqNoPx6cDAGfX9ggOYAnML8HEQKajDC7cz"
    @"AWGgVXr5D4PmAnYrvHZXwjsmegy6nujIbdb1AH4RNAXIKGFQ55QuBfA2oeJbRvCkKsBUcwXi0AuAqRRHTQD8I6iOHYmTr84NIimoXGZ4g35UnP5Vbf6YP+Mw"
    @"3w/nEJY9EYa7j1eA9BMvA4Fqs0L88yr+u2s8EuG6TGuHyMyLMj7HBkmw6SwNxhwB/AtosEVXLP5GjTjiVp38x3ljfQ1UM0+HMPwiBQ05aauN3hVhsx4T9rMg"
    @"Ys3nQWXJeVCV5adAbbhdj85AKhxM5Nmk0ZAqQ6mYMJQGEHA6nUAMos5+AoRkn8+n3IzipI8TF7CqQWaR/3wngA+DwMzGkKoMB8XnpUr6Cx4ALwZN53kFO6lZ"
    @"EfJ34QcZobQHDmG1/FgFQcd4KMuJmEd4QF2bDSnAdFgipMDvBPBfQWQWKwaHrngGeo6rx38FBPilHJr/Caj0NyNO5qqv76C4B1mhs81g3a0XTMtUyYdJ59oQ"
    @"xJ8/BvAGELHIDHGIh6turIA4B8dDFWDwgRtlqLTj1mdPRFj6ZdBUW9eG6oaHHueNl/RAlofRB+8W6CJfwyKoLr4PwIf4eluegaNVpkjH+LNTUREwfTT4Ys9Q"
    @"1sjzrG8HjfC6CVSJeTeII/AwiOqLAQaGZGE4VgxpjUCy5vewg22EFKB65h1yTNPxjfK2I1TTTQRS/VEQq+3tihPQ5uuZ9yjm9vo+Za/LTdFtC1DyOG+UrwH4"
    @"P6IKMKwqA7A6hnsFVC83ip5rCj5zGYrfAxrb9SkQL2An//3vglp1u0OKVrv8fRK+hocmWBgGdZgM5KNY6rlwvj9n5XbRiB6E8TivFVD76RyDVjOie0zyB+Ic"
    @"3Pay2gUdPu2XRdh/P4AvAPgbEKNusSLST6+oTDLz5L2IVDhf1i7k7/cVdjIpqDHnD0FEICtoyGbAiUbS3Jjy3QD+ltO/KDiAwdMA3wDIrLKO7aG+m45pepC7"
    @"riVQn8ACL8hTRPjvZtMnPcglZsAoalmE+rcC+Cc+8T8D6l1IR6hc1AVRZV8spiqnChwt+z1nxUTh+zjCeD9jAKlnRHhV1PBF/l7fAHUeLkybJkBjSOF/qk7w"
    @"9SAlWTew8bAAlSAW07gYWD6nBFFf/wt2BO8GDcPYIICprqDHNj3YSpnvlIpS21cA/DOA74M4Cl1PJDIKB5mClHifBDXktIUgRzpAmVTOGPxPoDKhBXC1p5ux"
    @"7H30YQLu9N8H4GbGAGIEHkBlU2ncr9eBxkftEGoyh0GCEZ9nj9/2UFdjhdBjRIxAeK7FgiSp7ucw+M2gvoGt7NTawvG1xPVbFJ9bYBQ6/gCH/G7jt4S4xqht"
    @"F2+W89kJNoUDbFVwcMQgYQ5URMk1PYDVNjv3u0DdhmZAmnFIATwL+WoQmvsyXjRngIQldoBIIS8AtYQ+w05BD3EYNQjYb7jEIkg96DZQh9pRsdFlbR6iqyxP"
    @"KpAljBFzGvIdoa6DEUdL0pm3+Xou53RAzh/Uo72Tgpspa8hHFREdPJv/KK+7v+ToLp42AHAYDkDaHIB/B+CnQcjuvAKO5kHNIFeD2ju7IMbYsloM6Yjz/6zh"
    @"GkYAXm0QCv8dEHp8F0hb8Mf8vU4RgpWm5DW4z14HQqfvxYklSzNikNS9DoFKc47mG4loMlL3LymxkaMe7cZVnf5H+fWvAD7OTi1eo/MhRl4FcA9uE+fMFwg2"
    @"VyryVzdieoYjgueBEN+97Jl1NSH2hGmm4mvux/nXo6QTEIK8k4GsawE8l79HM+cJaPpsBMdQvBWrJBU7hiqJFWXJPSA57R1i2IYk+GiOP3qUS7NSx6KheC/d"
    @"B6kotMjR1D0gAtWTSlodwQEMfkqkIB74O0Ay0i01003qr7trmAcpxlwCqjk/5smH4engskMiSBlPhSIVv7prvhbAb4Mm1bycU5ysseNl0ilHTLkL1LHYGIMD"
    @"iBRl+giDZ2eBwN2m6gnwTRa2OcpyqEC7sFda0eZr/yEI2L1T3M+pCv2H7QAsO4C3ct7fUCG0UeFhQziF00DdZIdBSj1pzjy9ylxX8xlku2iHF/xlAH4NwG+B"
    @"BkucqvrKUdHMOQdOHuQF2+lBOhpVmhRxFLAbJKN1mojwrHLsviEhpsAg17wnvi9lkBt7hTf/9wD8KQN/PicRHEBFDmCjcACxp1tMh12xEJHYDJKXegInTu6x"
    @"ORmHgw7XsBkjvrsgPsAv8sZ/Bef7sQC9Zj26c6iAq95kzGHfGMpVvnQrBpUld4EA3s3qupoep+2LCHzlxqQAscn0yPu7gk+xD1RS/e8gENenpxgcQAUnRCQc"
    @"wJvYAUQeko/xaPTLbrvN/LqbT79IETSqdgBRj0lCbgrNT4Okrt/C4W+sFvaMBw2vov7e5ve9l/GGUY+xtj3EOZ7i1wWgio4R5UEDP4U3K4KzfWYHROg9cl3/"
    @"vMsA31MA/h7U3/GAwirstG7+YVUB3KKdBzG5zlabwmRsPEkoifnhncx/p0NfO4TT33gkp9x32cE5/m+CpKxmRJjb4lN/VmjfV9nU1MVqF91+jgK6GJ/8mG9+"
    @"3uMMpm3nZyY7/5KM528z2KORZ6P3mzVoMkL/ZVB15k9Bbd57RGRip/nkH3YZ0D3cV3J4OKMecNbiSjyls63stZ/IwAGGxQWI+bqvA3EZfoavJRZ/55RuGp4R"
    @"VFWCXIn49RucyxqMZ8IyFBBqBUnoUVD1ZyNWZdUS1f9RpKvUlGAYSnGRJRDa/3X+vQMCUxWBhAig4i5AB/JdDuD5wgFkUUa1Hpv0+nP8+g5WG1+GUQoz6p5s"
    @"ADH+fhdUopwRJa8Z1RCjFWtMxQi3nHV/F6gPIB5hFSCrVVnfv2d4wx3hyMj1DHSEdFkRfMQMMFHYpZQXAngtqEJzDt+zYyDefzrtmhhxxSOqNYV3A2gAxDqV"
    @"80eeUVBQpbZIMM22cIh5n6Kc5g3hoh6bUoaXLgrZyuH+rzLoNyM2fiyEK/RIbAyxDOdUaxwT0YxRtcaqSE+CucdAlOl7+JktqY7Btmest2+8uKkAr2jyetnM"
    @"m/+5IKrxxRyl7OPrjdReiKZFESgewukvb14HJBN9uiLy+HJBLdMUK3DtNF5Yj6sqgi1B9DGeHNOh7VeAxCneIpBteeLHAqwcxShpKc0NzmNvErp5dVik1pPK"
    @"7WMncAdjOPfwszviufdxH2GZMnhO5OEHxHwonc+O4GpOWZ7h67JKvMSsdWcQD1llaBlE932BCKETz8bMGgohc8czGVi8kx9WpHLRXt8xUnwCTVt1ZbbXAPgD"
    @"AK/i/D4SjEX3Xs0xKBc5Bl4CorB+G6u9AbYGswl8cttubS2AUPgH2Bl8BzSL8Xt8Cl+gIjBU0JhjeugAuo09z5/9PI4M5nldLQgAs+FJU4MDKMDlbvOifbEY"
    @"LgnVPII+U2Jlv/lZvBnvEqDOILryziFtBPBLfPJfLIC9Wf48TWLCiKfIOm0C5wTuFjiAranMnHOqco5glx1Xm5/l60FlYp1KJBkEsCLYgMk4aCJRrekKKvr1"
    @"IELXRnYEi0IGPZ6wSdFjdQD6Jh3n/Oty4VFTlXubHuqt0mk0QMyzJqg/fslzeuStY7uo4DzQ/PlfBJWxZsXmb4oFEA1pSEXe9KorEPUfsROMa8Bgy6Pl6IC5"
    @"FqeEvwfgP/C6sCrMjsUr6iEWU6YyZT09HRC07q0gavf17KAsR1wrFSoTT4UkmNxkDrl/HqhGrL0x+siBWRU1zIGQ3YjzynYPuW4fNiF/dgMvxNdybtgQdf2G"
    @"Wpzjzq+lou7DHEonNUkBNFknVt11M7ypfhvAezginOuByWBEg1QbIhpIxdiyrQIwPJ8dwC7BRTFrBReIh7gY5I3az/nWJQJEs33QeSg5sViNcr6Uf38/P6Co"
    @"RwgYK+DwFD7x3yNKfA1V1zd9qKajzrG7QhRkF+fRS2NeiMbzzGMFul0N4Fd48/8Uby70AGVHoWsADzkp8uyNU3jNXsW/P8gv5MSfploPQN7wRV6s14FKeg3B"
    @"n496aPL1Yo21QIi95Zy404NU4vK9BoiX8H4A7wSxFB3GMO/p4otGtDhRgBFoQAj7t0ACmuN2ADqKcyf+paAy6m+BSsFnlijRVnHiWw8eEHlwB930ZYQa8cns"
    @"BK7liOFpxglQo0pMbTAAX5tmA1RqcVhAS5T7ohw94Zof4Gq869lDr4AUejqeHNKBSjtA7ckfAFUl1uPZjL6y7LNR6BVaMZ9gBVQJ2DUmB2A8nZIuSjsPwC+w"
    @"k301O9l59UyiEU1ayiNXbjyOLPaUKV0p+rn8HQ+LSUImBxGsliBiPMLFkoJIF9cLgZBYlYxMn4ETibruCEQyuozf/wdKQz7lzf0aELHnLSBOgiT2tDw1X9Rs"
    @"bJkRPIWEHcH3QaW1UZ5AvgXufnYGiDn5myDa9Jn8nFtiE9keIXcdgEzNQ2ko8ppzBGeChpuuA5GdjnkiGdtDcn6qHIAMk/bzQnGh+0yG9+wVbqaeeQMb2TOn"
    @"DAwu8u8v5Dz/3aLWOyM2frNGIX4eWxFjy+/m16gk0yLPqe+avn6SQ/23gLQeXTrVygD46nyvjcCojEhXtRrUZlBj2Dmckj3tYUiOIs2ZCAdgBC/gAANv28SN"
    @"7eY8FYxnKKUVk3qu4UX5CKjc9PsAXsef1RIPs6WiiLovSCNyUqcI/CBopFZniNevw3R9Ql4N6pJ8N/9+g2qMakzY5odHlDYV36UhogAn/HI+p7UJSBNyRTFF"
    @"a/2d4xF/llOSmWVAsKEktKOcDSLGA9y4iOIqAC8Bjae+RISgqaoBxx4RS9R8hHlXcOkfZxxgecg5tNZhSDgEfhsI2X8JCNmX0VziOT0nIcIyGY5AlmAlPb0J"
    @"qkidyhHmBkF3jieBPRiPoZe8y1HAZSCyRSIENPOAJdJRJB5Aap7Dsk0ZPf5NdUqZCRlfLvsrEgZVb+H80wwZxJXl1xs43P95TudcSiW5GhJYjdYAcSZSGFSk"
    @"2KENkYaex7jAHs/+Sqc5ApCn7RE+uZ7HXjMS04H6SWlr9Laj6roQYXHD47VbE7j5U8H6W+KfHQT1uR8e8vdw9+pMAO8C8Oucaq1XWgixyPtbA4wLq6PjNUq4"
    @"xjcCr8EO8lyOPPfg2cK2dpodgO4Ye4oX1WUqLO/mmFhkPTMEjUeGuimcQFOEqVEFuvOjPvkljpLyxv86A1DD+A6yHPZcDvffDKqiNJRoSkuc+PEaosqaDGcI"
    @"j8q1PJi287o+xLhAt66koXgMNzMV+ewuBo+2CU7ATMYQ0X4ahN2MufS6vdMMOLnXjOGeyeipzRHOAoAbQcq8jQEWmK/kKqsjLwXRpV8mxoFFote+5REAXatm"
    @"VQ9BmtFsFDMuch5ozsVOVUqsjQpRPCZv6m7WQV7MzxMluthD+skTpkaCG289aG4VYpjjXuQu5XFil99g0GnQrsDI42xaoArK+0Bl2znhnJuiU3KaZumZDFzA"
    @"ZMjKr+co92l+TrZuEuTxGHnj7mcPM4ByKS+s2KPOkjcdiD3ClUVLMTZj2ISpyQJ0lOBlUEPQzgFJJpHquEz5pH8rSAH5QrXZI4GAR9M0SNOzRqIM6rhcN+tA"
    @"fQQPcDSQ1ok+HI9RW14Cdg9wGnCR6tCyPYREswQffJ9TpIdfjv02qiFp3MChuxZHCb4DJBVe1gEYBYim7IzfDWrgOVuMb3M4isRVptVMxuFiPa3sHRBpaAUk"
    @"gtKuUw9BPOb+cXcNR/kk28F5U5wxnqsKAUnTp3kkEV13svYOD7Jtx6AMlIh+gLtBlOBB5K3l5j+HT/23cw7bEBHZrKqqTN0o7ZwUYqvUnBOhhXAPpwO1wQHi"
    @"MW7+SHnNQ5wOXMIhkyQPJUMON6XghhWdim2Rc7vTb5wNHs4htvm1k9OAdIAIwP2/60FCHa/jKKAhSqczHkKPXasqORWkaNJZd8ThsRskaRdNswPw5e8Ood8D"
    @"qgxcCmrBjMXfp0OQ23Ynn9Svt0KBN1HpwLhZbZJp1waNDb9FRChlbCOoeecDIDB2VvVLzGUMO1kLEYAd0myJNKM6tRcE3HbrggFEY1i8elyzBttuBk1u3S28"
    @"p1Wz3op4T+t5SW+9LK5lGavae84xPA6S3zo+Zt6AUcCTUbJlZUQxtoOIPR9g/GVGRDpzoMpMlEFmKUJz9d1/3/gvOyaSFSrUHzBqjoPsi1jHz6w2hKDGGJDT"
    @"rPA7Erzzz4B6r9/P6cCMCKkkKy7PaWw9/9aK8MyqUM3JbS/xxv9LUNfXC1Av/kaq2m2tapLKcvSRGNryGwB+gqOAljj5mxkTjspyKKwiNcHTAWrHxLPoVjzL"
    @"UUeNkVhXTdVVmUyTAyg6VeiTIFrlL2BVnz9WnPM8YZxvrlyqABo5fMOCRlx9EcD/BjHuXi06CG2fCbejClnlNGWbk9XnnNurQW3SVwpwrykiiqpPxEhNOm4r"
    @"abjGGCJSfZ1xhQ5lRbUVu0PooKCp22mLAPIwrOQJtx/AR0ANJ6/A6pgpyY0vkwbIjjpd8z8G4F9Bk2RvA+kKXIRVEdJxt3hqzf2ZnJOCjWi6egNW6/uxokk3"
    @"hiwY6ghMyyrdGKfeYlwhyOywma5gZ6ZCHPchoWSdBAeQzRJ0G/xBAB8Csaku9pQGo5zhfyrC/K46SV2DzU4A/wTgs4w/OPLLGZyOZHES7IgmA9keDrOXiIrb"
    @"/A0AbwRx+s8VTTxz4jSuOkqRoOUK3+dDoP6FMzj1mKkBt6KKFMCqkrFceymo9+XWEofXVDgAnxNwOdStHIq/V3DQ3b9tZlQW5IAJiJys6xlAsR80auvjIEmx"
    @"VCjZWBAvYROezfkel0a8jADiDAqq8TSrvB7UxnuW2PyzKo0wFQ8OTUVFZQlUA/8sqMJzllJ6HncEmlSQBnTUfU9E1PMtPtBqVTVp1Lwk42re/wAiCb1TNJ/4"
    @"ZMUlUUZ6YKs2RsIn0T383jeKtlojiEBNkOLL+oxNMg4HEImxVVYp7/iwjganUO/nsN+o1l3kYFsWDfndfT/OJ78FVVM+DCqD/Td2PtoB2DGNPa+ClWeVipKM"
    @"PHcC+KrABtK64AB1cwA2Y8EfBvBBUCvqq0VTyopi56We0CvFiTJix3nj/zOAr4F4B3JUmRxNtZ5PqmYNZK18BBwnS5UKAFPnt1cA+DUxUakhiD365Bt0A1oB"
    @"8q3wr8sg8suHQZyFKzkFiXsoQo8Df0oriiIilfosAPgCrzlNLQ8RQA4AKxXDMD4G4qdfKv5fx0OtTDzg3zFQz8HXAHwFNFDEqvKjbujYyvl/hPENCuk1fNMp"
    @"LJ3Dkco23twd/n77QANQLhcRjYugUoEN9JJGK/LzDm/4tsj7bwbwZ4IBdzlfZ53EWLXMHEpMG7LqZ+6Uv1uc/g1PChkcAPLXvm/nk+SXsKo+G3lEGbpiAR7H"
    @"KmPuGwDuE04jVQ9dzjHogKYZbe3RkzCKBexTmHXP7lRQu+4lQgbNiao8CpKmuoDvkyOhyFp1I4cac54SXyryfHf6HwMJlnyEc98WX9dFfC110cszFUStVoT3"
    @"VhDJdgP4FIjiHitnESKAgovNLbgvcjRwPYeSJ/GCaoqSTgckO7aLncbtfBq2M8aFZ/H7LwYh1VmnlRkDNuIWziyfps9V4JWjNLtBl0tikpJRQzyiATaIEWWv"
    @"tuJW7AORuT4O0i5s8KbYws+sVdPZAHYAtetEbfAFdoA3efJ+G0DAculBAqqn3gpqhZXCFLEKi4/x6d/xqAelnpBam9N3m0f9Gk5SQd5JPUMvpT7CelU2TTMq"
    @"GnmZfEYBtMuqqvIYqGrzd0Id1wGzp4OYnVodBzUbbV4U85CTmxPRqfk3jF8N6mimPgLwLVR3+ixkTF+xSmtQgz6+jS/LNydziN0cs4ag6aGKbJVTsz3ov8jo"
    @"X+/VpJX1HLpqRoHjUtwB4K/51GsrJhw4TdkqeAcG9dX/y7MmOyL6kVHlbnaCDyjVIBvKgNVEAlmz2Hw3OBUPII9Mmfs/p/Ji9WEM41yYWXMU8/TomwwlpV7S"
    @"Z7phqy0WvvvMZ0BVlU+KRa8Br4hxm40iOsGEKgFBKTQbkfcfBfA5Bv60SK1RpdzgAAYohfWrIPSTYzZ9lF62M76ACZIPtwVONV/6k6g5jdqRdpQDWOIN//cA"
    @"vsThbkNhES6iOkUNaoknZChL1j1bUilZl9PTmxn4W1TfsZYThCfNAaBEK3BWycVmCJNADLvcWNOhoXlLSVkaClY16NgePIdUNLh0BMr/MIhA9RlQlcWKU19f"
    @"o5vOfJHi/9sJ1BNwiD+UfsQy5/3/C1SBaapyNOroBBprfPNnhb5ZjkACbGeAAEDbh6loxnjSmz6qxQ6om1F1buPpbUiVjJWWSHNNLk+ASqqfw6rGneZSyL54"
    @"iPz/DOEoogkUDpEqUVaVnJ/mzX+7B/uorTXW6ObPwzBED2BsPYesUR/RiHFhAiYnqhyJFmANZKZqlHqiEG2r1JL28Mb/EgjsO6IINGlGlOE2/Dmgcm2qBrnU"
    @"PaWKFLq/IipNiZhv8SGOiKI6n/hrJQUY5gNPQISararXoM7hatZ1dQVAZQXyrluirUfJxuW5u0Bl1xtBAqQH+H1mhXPod0+3YbWlGhMEAFqlYdBWw0K7ILLV"
    @"RwH8o+BXpJOw+YMDyLaT2AGkHo8+SYDgsuKeLzM4tZ9/3YLVOX4udF/hv3+MN/xtIOnxw+JETAqEuBZEpz7X08GImgN+seCeWMWiXOF06GMAPs33NvJInwUH"
    @"gMmSeAYI/NsyoYKXMpKZEd14roS3H0TSuQ/UKHQKYx0JL+IDvOFv57DfKmFW9JEf80Ump4PKqnYCh4bKKCAWgN+DoAa1fxHpk52k8D84gGzbxDiAr1owCWq1"
    @"VgCAXQUIPgLg8+wAviTaco3oXrMefkFaks3WBAm6bBD8gGhCoinrkYpf5qjof/KvsSp3mknZ/MEBZE962aIaViZpwVqVs0pw70EQU+9B0bO+5BlsaXLMscuz"
    @"0FMQpfpsQVuOepRe63Yvpcb/Er++CODPQT3+kcJPMEmbPzgA/0NvgmjALYxHPr2M4q5uTW0LlNo5gntBSPVNiqRjMySyeyn1FlnkLU4Bmpi8QSKyzr8PpGb0"
    @"Mc79mz3yfROqAJPrAGbZAUQlphSPM0eFmBvYEYSVp0HTgz4BkjnvRfNNMzCRsj3sFgSonsLvPUljxKWS8n4Afwvgr9gRxBmisoOWrIMDqEEZbY4XbTJBm78j"
    @"QL5l0Yt+B4ia+lWslu+sZ/NnEaRsBQv6ZH7ZMUt/o2QL+mFQY89HQN2leXL9gAFMqBNIQYj4SeoBRzW/5rYArA4C+CaoNHUXSPvQqBmLo7TTQICq8YzTrns0"
    @"0OaU6RMg4lNTsSftpC/64ACefeLNgcqAVg0jqeMJBYHcHwPwY1CJ72aOAKAEKkcNvBlQU9VcTQRAi6L/R9mZ7p1koC84gGKDSWaFCEjdGV0pb/ybQXJnt4Aa"
    @"c7ogDoDr2x8XOBVxNDXTpz+jjve1w9HTLpxImcZacgLBAfgxgHmP5HgdOwHboIac/yI68qRcV9Zsv1GRVSK+l7Ea9z4JJKo2RwD7VUuvXUsRQBT2/gmbKhIS"
    @"Y1bJiNma5f2O2vs4iLYbCfUi62nzNZ6pzKOwZgboaGoqQy/v0X7GVIzo7bdraeEHB/BsJyC58XWRrs6qNTfFXL8UJzbaWM+CtmPqZqxjJGU806JdM5RTN36K"
    @"HYCdpNp+SAHKOUIjUHIJ/kU1OLGM53qtmOabqjHUyKmcZEcEVEY1jAA0h0KOiXcYwB7R5NMZgA4dIoAJogJHKtwzNSeqzHr6602NwLR2hkSbrVm9X/c8LIAq"
    @"KR0lcoKQAqzdEqBRJ348ASnLZhHJ2RqG2ws4sSGpjmG0UTMWLagC8IjQVIgwGRWM4AAqbgyKan6tp2FVuwA1O60siIq87Lmvdbl/kXL6Tj7tURCvwhYQmg0O"
    @"YI2UAtFj/HjdooCTAVzmyU/rYo+BgLSOACPrWFkxAkRNAfwQBALGPaTYggPA2gcH6566bAAJe9R1QT6B1QnMVkUn43YAiYc3EXPaco8CVOEZvGLCAl/bJUEz"
    @"Id2Lz2FHUEfQch+AH/Fm6uZUEhol3dfXFbkMqgAYpQikhVKCA1iDlqo2YDsBU5PPA+nuJz0kwscVWi+A9PIXcaLo6Liv0XrESSDK4yf3cKhmreAAwQE8Wwt/"
    @"BatThOscBRgRum4HDd0wHo3+ca+vFKSe8whWlYbbNVh7RlVPYtFS3eT7GSlpcCgZ9eAA1liub0H878UJyf/BofVGABfUsH/BbZ6HQc1KS0KbMK0RuUresy47"
    @"g7NBsnCafj1Rop/BARRfFPtB7Z+NCQrzZgCcxThAt2bXHPPGvwlUWnOsupURD4jJ22DlHMAOjqyStUb/DQ7AfxK48Hk/aNhDXHNvr+vqZ3DemqKeDupeAF8A"
    @"qeoYdX/Lbv6qHHTkmQa0HaRmbNca+Sc4AL/3lwjw/h7137ra6SBSUJ3ENmQj0gpoau432SHMlLzGXvV4i2JUY5tB7jEgHYPTPVOhbE2dbHAAFYWA8zU+SXs1"
    @"Mm3lvFULnNSFZj0L4gP8sGIegBUgbkeV69ICUZxR5b15kJhpY4LKwsEBVDD99XQQsSadMPbietD4rWYNUxYH/J0P4BWgluukwjRIb15fC7Tpk1JoDYWmUDMK"
    @"GMAUOYFz2AkkA+Sp46hlO+BqrmbtthA6C78A4CXC2aYVNnHpFt2OaO+2BaoBEgfYJOZDrMkIIOgBnFjmiUH13y1DbgeuShtPq/2eCipdHR2Rc88K5Y0Km7sA"
    @"Xgjg7RypdAeQB9OMvaYY023VZORZz/X02vxyjHrK19pSZUATREHXZvdfAiqjXapELKOKiEbLYoE1K9yg8n02C0HTUZ7wWdUJp0i8hU//iyuat2BEmA6h4qPT"
    @"uZaI5EwBPMUIgdhmHycSHMAaCP1dKHomRwBVyoE5dZmmUO8ZRnRh+cQ6GUS8SUd0WhlPGA7RVWcAvBLAGz0DRwf5PPcZx0DdhovsBBZAPI4tAK5Sp3rRdDBe"
    @"SzMAggPoLwd2BaovpRkRRkLgCqYAQGVynIZuqMn2EZ9S/dKZswH8Mt/XVICUpqATNaqVOAU17HwWVFlYBk3xeZpf72EHUMSJWw+oiLV48gcH4CcCXcZpQFQg"
    @"bCyjM5C3YSfPwpPvNcsOIBrxTAPj2aiOR/FWAC9Vm7nMxrJKvHMBwO0A/gdWGYYOBziNo7nZgp9lPLwCTbgKqsBrNA3YBOLTzwgHUEeRkl45d5MXfmMMqr/6"
    @"YEkBXMu5/1zJUNwHeAJUUtwL6i/YJX7uBFxcd2RUInfX/z5FELyYigrAxbxwYk/4V2cHAKVgdBanHKNqtjGeenvMOfhv8n2VLdamxOmvZxscB8l13ehB/yMA"
    @"l3AUYApKkWkuwZoF/4IDePbiuhZURksz6KWjQtHzDrDwRQAGBAKuGyMG4JhzPwPgNSqdKqsILJ3GMof/3wG1GBs13nwOBOTOlZhDaEfYgBQcQA2GUjjwbyMI"
    @"AFznAeoGVX7pNY67m3PgZK+N44QsnaLtepxYCjQjJFHFoIrHDgDv4lM4Fmh60f4Kq2i9bmTXEwC+DkL+uwIU7ILou+eIz4sGSDU0wzAQgSZ88KfNCP9P50Vj"
    @"POQWU1GKkQr6ayQ2jOlTFnTtqHkpqXOMZ4zq5DLqOzUAvA7A83lDNgZIa6zaiF3e9LcCeCDjdD9V4CBxwc+0njHm1hPlBCLQhOr+Zy3ec0DttFaxAk3FAydX"
    @"lNzYuhwbw+bgDRhVctwyhgEl7jteCeCdA3T76Qg1Edr8SyCl3htB9X/jadQ5A9QY1RqAaQhPqTbwANZo/b8BYv+drOrMqFBj0CqpLqeI01DVBp8MeTNHlCAd"
    @"XEM4ADNCbX2XzlwGEimtMsV0If4yaBT6nRkO0Gn5zQsGX5l1EWWUUm1wAJOJAdgeofkp7ABaKpc1FeoMtEFstd1YJas8Ayo7vpQXa4MXXaMkZ8DV12dUCoAR"
    @"iKg6B9QCcCGo/j4oeq7ZhV2QwvC3+B42PB2FEV9Dc0CmYSSwoDhDgGVNpAKNKUb+3al1OlYFNaugAMuF66SwnwbwQc5dj4HGTh0E8JMArhbNR6YE9qBThCao"
    @"J8CMcBpPKhD4M0QKVRVBywmKfB+kMGzg1+czoi9gU8FnBcU2bChhWLsWo4HGlCn+6FpvDKqbb8/gsw/6uR1+PQLg70DUVXeyJJzPHuDF6tOeS3OG0UY1yGwY"
    @"MQjoPmMTR1RVpVISLzkE0hXcLfoM4AFMD4PKhG3RyltWMXhDRVhGKAPWlP7b4nx1vQdxruJUdADWA3zyx3xKupD/IEcHyNj8RclCzmFsUKXMUbUDb+McvKqR"
    @"6pL6+yiI+pv0cGwJ/7sDePY47373znrGr58B4AU1HxIbHEAJCWgXnm8CodbGMylm0I3vwv8VkCDmiogK2uK0ekoh3qZgGiI74yBYePMjOP31ANWNoMpGVWmH"
    @"q+MvA7gNRPs1Hvaf7NXfCeA+0YWZKK5FmtEnIcuZ7nPXg6jMV3qeTXAAE6r5J/PG00AlQFR4+ht1ch0G0VYTTyvrEkiBuJtDsKLf58kZ9+sEqDnKEusGrIpw"
    @"2Arfex+Ar/D9Mn34HodBQOFeMZbc55BsDuq1GxDyNhElmhABrJ3uvx0iZHWYQGPAh6xJJI8AeDwjtO/w3x3NICEViTp0+/HcGNbRnKiuVJVGGQD386uXKrD8"
    @"+bcAfI8jhy6yVX/6EYFidqYvBnDNWpQHn+ZegCao+WedeOCNCu6JFaF+FzQYc3/Gve9yWHtETagt+5kuEpjl7zWKE0vP1JMhuq3gPkag6skRVaLrFQXsAgGG"
    @"+/g52ALNQBD06hbfy7NAFZvZms1eDA5ggMU1w+H/rJDpalW0GaQW/sMg+mqWwOg+EMJtSg6ftCryaPD3mB+hItCw9A6dQ9unBp/2muTsnOgtIPB1UT2XIntj"
    @"RtzLV4IETbtrZTLwtDkAq5DlLSC1mqbYOIOE/ymeXRc/COAxoUvna+w5yBFCVtNQkWYnK5xba0QnlXz/FQG8DdpJaUWUdA0IsLWedEf2WkiH8DiAb4NKgp0S"
    @"Az2McqjnAvg5EM04XSt7J5rCtl/3nc8C1ayNalkdVKhSTht+CgTyZZXsDKi3/cCAOvm6ctAYEwh4BFThgPo+dgCyVgfUWHSVUufNij7kffg2Rw/LJSs8kUgH"
    @"IsYCXi1anoMDmLDTXy6aHSDGnAQAq6qJR2Iq7m5kS3QZPjUPKCJQ0dxd99rHAo0fZYl1D4jvkFY8pHQbgNeCQEabQdVO1XAPcApwOzuAtscp2ZylSOdQtwF4"
    @"PVaHhk58STCaItTfKoLK2ZzbpRWEqlDphQMBH+ZTERn1aKcJcJT/vVEOxBQIlVNVYmyN4R7vARGb5LguO8A8PRfatwA8F0Tbtp5Kiw+DSfm+fl1FWGmJ+QMy"
    @"HbgCwMsVozTCYEpOwQFgtM0rM6C+8aaimw56AsoKwGHO/3vVod3/3c+n1KANLFJ5eGYMrdZH+Tt3RHfgIFOAIvHMTgNwecEIKQX1DvyII61uQWwlUtRg12r9"
    @"WjE9SpOhTIgA6hn+GzXxZWsPDz5oU0zKJ+HjOU+d/TgRrS4CBKaeKCYeYZ+HFRt9BcBD/F0SdW3pACO/wBvv+fzs8kRtLlXYDWohPiqcUhl8IhIci0tAVQGo"
    @"6MsMWUIuOICKbHPF+b/etAkI/NuT0zkdAIGBtoQaUVeJcpiKnVqRKCThtOew6INI1UleNK2KRJPTJZy6FSEatUH6gY+rtMSUcHCOJ7IVpHe43QM8BgxgAvCA"
    @"raDJr3GFo5/lol3iBXckZy3+IP/btCRyrqsA8RgbWJ7Aqk5/WpIUFHkUh1zn5o4CzjEVYOy9Agg0BSItq053xxm5HFQVSAeYcxgcwJjEQbeBGlfSIfEM2pwL"
    @"L+d8Bkc4RE1LoNS+5qF4TK3ehqOeu0QrdKLmL5ZVbrLstM8r0GrsIqGjHAXsE1FAmYYnSebaCuAneC2V7eMIDmBMdhKocaWf6q8tSABy/36Rc8+8m2aRnUBZ"
    @"Ao2PH98cw2AQAyLe/JB/NaIzEiWmFWn1HZcGnJQzDZD/5ruMT3SEE8jTf2E8qWIEKrNeD6pOJD0AxOAAahT6pwJQkqIS0QCDORIFdKWcz+/P8R7u5OiICMCW"
    @"VAWK1EZsjCAvzVLLeQIkeeYwio6i9hYR2tTf62IQAp/m/H7u3uwGtQrLCkUe3oU+IGR0tRXAi0B9Fx1PahEcAOqnDNwAIckyXDYVEWFcCfAYA2Emx1APt0kW"
    @"hDMxJZ6hUTyEqEJp8zyDSeXnPAFqgZZ6/V2Pyq4pOG7MgMqBOwqAt13h/O8TkVZaUOo7q334SoFLTNxIsWnDABxPfl7lc6YCxyI56cc4/y9C5jmqWlfzWqLE"
    @"M+RrlAxLeULuZxzgmOL0Q/DyTUEMQLbnnlNgToK0+xmjWCmxQU2GbqQEJhFAQEyEDuKs2DCmgn51I1h9XT79V3LkvLLl9RBWefRlIgB9sjZHOBXIp7/4fawq"
    @"+EgsoAgIZzzz+SJ2APMFNnEqIpMHRdNSOkDE45iBmzgqCVWACakCNARLblD6r8WzS0kpn4DtnDmq+/tjIjSNCiLd8FBWWyNoWrEeoM5d/05OAyQjsKMaemzO"
    @"/D1S2v87QCBu0Z6Jo6DegEUxmyEdgHHpwMAtkyqwG02hDoDbHGaAUNlkAGGOZXZQIN825yZa8FBVTYmN6DbbfInRWFWpL0d8D+7kyCb1dPIVLXFKh7AdVAko"
    @"qnfQ5cjkKXYAnRKt17o60VAirMEB1FwLQEYApuL3diDgMwL0yvseCwWcRi/arBG58ijbVn2NOd8AkYJSUXZLPCW6fqF7pNbsFpBirylRrXgIVBJsiyigSCSh"
    @"N3rMDiCkABMiDKp7/00F72kE2t0GUXuL5peLHoDMlmDNuY01SmFQ44kCmiA9xLuxSogyfZR5swBAjfa3OAowJWYYHgXwTVA1oFuwS9AoYpIVIqyN0Aw0eerA"
    @"pmIQLGKA6TDy0UzlybSoOtbyOiejSk+RGBO+bsSKQL5hqLeAGHip6hmwOdOBVN3fWHRzNnIy8HT68RAIDEyF0837rGOPeMysmEVoJ6kvYBodgBTNKIMB+Bat"
    @"JAMtcP6bR2ZcVgGWBTjVLUgFjjyTctdhVUDDDJGi6gv9UxGJ/ADAHaoRp62qJCbHOtXP6yQh5xb1uNdGzWuIQKXAO0CErSL3O0uTsOkBhAMRqObf21Y8bMSd"
    @"VAu8sIoywtymKHN6pJ4opzHAhNwqo4ODIFGOvSoK6KjT1/YJ3Rvq+W0WWE5U4HlF/HzuZKzGltAriDOqAiEFwOTNBogKAm8mA/xzJ5zUxStyii7xq2hpKisi"
    @"qEOHmiMA3Q5C340iTeWNApwuXyyA3I0e2bM8J7icNfAgVvkJeTULogz2qA0g4OSlAoNsNplKyD/vV12AeU+EFU4B0oIMRZvxqoN0tbuOJzkKkA1PkUqd+m0i"
    @"mXtH7ADmPROQbYZKkz6l93MUcEw5AVsg6pPj5ExwAJgoWTAzIG9b197dYj6gynm2gDNaGqChxKoT1tbIAVjOuR9QPRlQhBzTZ9PJXH+O0wDffbI9npXka9wE"
    @"YgemAhDsV52IPFFjV+k9BgdQY0uUltugjUAy/3ezADslHEnCkUNRURCT0dAS1STSSnmzPwKS5joiQLdIleKKjF2bB/EB8k7q8TmKh0Eg5TJWlYO7OVMJoxrA"
    @"QgowIbl/V9B07QAnpc3YxEd7TLHpl5sulThJbA5gsA4krDanAY+ofnwUTMWsoARv7LP5TQ7g9bvstF3b8nIfUNCqqksCAhW7wQFMBgegI0Z1pxVufPf7Y0qC"
    @"PO97dkU+akuMB4dqb86iptoxYS0RSJ33u0I01PToDbA99AHd/MMNHhyhCGYCTk12sjOwYqRbL7anRv8PqknEwQHUEPGXqPRSDzygSBVAE4sSXtwowVNPscqb"
    @"TwuCgD5RkLrMr5Mbrg3gy5x3y/uXCBFR9AD0ZAoQCwwgyUgFbI5qyW4AXxIArEtJ2qK7MxG/12PIXCu3nURh0GnEANoiD61SDcfJYi+VcCpuUR/JyCdtATkw"
    @"3+YxNYm+YpBc2HeFQKeUUk96bGZ9vxqMAcwMeE1dEFvxDn52bhzZoupG1OW/VJRvD5YcPRYcwBiigTaftCsD3gPr0eVfURFAUd27Qz3Cz7KpQJ0WpUuRbgTN"
    @"TfBp9Pfq009VmXOTR/qsaOUkBjUsfRKkX7AsPifJmC1pRWRwCEQoSkIEUO/c3yoZ7oWSPADred9UkXnKyHqDwaglhSEUGRNuldRZjHqqMv0AwK2CMDWHVQGT"
    @"Xk7AqjbueVQ3BfkWAP8XxA9IBVa0rFKBNj+jNv/dQ+xAfOrMwQHUFAvYK/K2QebWSwDQzaJbLHnqWj5Njor3TDw5Z7+uRCvGn7VQL2DKaegfAPA1PnGtCOmN"
    @"p1ybKp6AUeXFRkkhVaj3XQDw94wHHBWbX5YIl/j5LvBrH2gC8S5PaoBJkcfClFUCwA/uyABNGzYj7DzIiwclSTzHROecnFnYa5pNpCiucnjFhhJg5DBPfnmC"
    @"3w7gnwG8XUwzdmBbLDa2pGtLp7CsyENlUwB5n/cC+BB//ktBIOMsO9MZvjaX5h0A6R18kR3DRO6laXUAh4UMd7fk+yRiUbqFejTnMJCs6MTNE+h6nEPaJ6S3"
    @"albdDC9eW6PQX+bdhwD8Lair7w2czzdFj8CshwKciND8OKirLxmQ92DVRKUnAfwZqE/gGpDo52bxDI7zM7oLwFdA6kJG0ZuDA6hpuiP19/YpfXjTR4kmayCn"
    @"ZP0d4E1ctsV4EavTdWWY20tKW6ch0mZrxAiU9859v8cB/AmH028QMl+xaBRqCKfhyFJH+D65ASSDdndqGvKTnA7cJBxTJDCAo4wVHBcON5m08H/aHIBRofbT"
    @"ohTVET3d2gn4ymzaAbjTaS8v0LhgeuGIMm0GlI4DOMUjuIkc6LjxcNbNmCsCPvIURB3+z/l5vA6k+DvH93VWNeqA781e0KivbwpWJyoSeoVo6340A/Q1fb5X"
    @"cACoZwNQJDz5/XySrFeSVanq8jMZpcS2CE0dGeRpPFvU0xYIj1MQSWY/gPNV9JLVLJNilcWWpV1fd8e8H8DHQfJhLwFwEUjyS45vW+F7/CSA2zj/flrcm6qd"
    @"m/HIrptJ3/DT6gB8pJgfgEo4W4VjmFH6fj6yTodPoaYgh3R4Ee8eYHEYUaF4AsDzVQTQKx1Z4etoKaLMTM3JKTJqWQaVBu/mZzInUH4jWqYPcPomWYTDADqL"
    @"tAYHBzCBQKDrUb8QNGuuKwAnSaJJRI7nBls0QTVo2Q66nzcvBigDGhBA+QSf6s0+wzeMqFG7DSNz7JmKwuNRcDTcPV/i79+L9RgrzGPcaU1wABMkAiK7Ar8E"
    @"kpd+G1bHhTf5vsSK/RUJcApKBWiJAa3DJSIA3eyyzM7pOIjqmpVHQ8iIzSlKrFVMx2QCHHLqud+2B/C5ZjZhcACjX2yuIvA0gA8y4PNmkNJsSziAhod8Ik/9"
    @"Lgi538MpxeEBBkTEYnbeU/xemwV2oTeL+3NLgWRt0e+gB5SaCUgHoj5qRyZs/OAAMOB4cAne7WEn8CiAnwVNez2J/03iERHVKkCHQTTSm0QaYRQ4VbRWfgSr"
    @"DUuxGjyqqb6uf70hRl8vchTxCFb5A90abhzTp4U4S93HN6EHISoIDiBvvpao+v8igM8wCHUFgBsAXMXYwDpOC2KROizzBn2SN/9nQQBgPEBemiiikuObN3qU"
    @"9OTEnY4ABPcD+FcA93o0+Ov8XMr+v7DpgwMYaBG5E3YXb+RbOB04F8B5oOmv60U3226QnNTjIOBvRUmD2QHJKHvZuVyEEwk9JqO0acRkob0APgXg0yUbk4IF"
    @"B4BpFAmVof4Cb/CH+WctQRTqCkUhyRdIBzhp9fDLA6By2GUATuZTfMYzBERq7y+x0/gHAJ8T+X8aHm+wfsBTMP90mUjk8h0RZhuPOmxagbgIhCDFIRAIeLoS"
    @"z5TKNIsgzvojIGbcx7CqbhPAsmClQJjgALLLbv1mzlXhAGRYvx3AixiX2A7iHqyAqhePsJNY5gjgIY4czFphqQULDmDU96KoJn9UUYhtMhSCXEowKybjdEWp"
    @"L1HXEE9iQ0qw4ADq1K7qC52ztPeHlWP3E7j0CZMWiVyCBQsOIMf9MD2m7tgRXoPJUCGOPINJggULVmFKYGrqlDCJGnTBggULFixYsGDBggULFixYsGDBggUL"
    @"FixYsGDBggULFixYsGDBggULFixYsGDBggULFixYsGDBggULFixYsGDBggULFixYsGDBggULFixYsGDBggULFixYsGDBggULFixYsGDBggULNmX2/wDWR9m/"
    @"JGea+AAAAABJRU5ErkJggg==";
static UIImage *SaoqiangWCAssetsLogoImage(void) {
    static UIImage *image;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSData *data = [[NSData alloc] initWithBase64EncodedString:SaoqiangWCAssetsLogoBase64 options:0];
        image = [UIImage imageWithData:data];
    });
    return image;
}

// The worker and its last result outlive a dismissed panel; no controller is retained.
static NSURL *SaoqiangWCAssetsLastThemeFolder;
static NSDictionary *SaoqiangWCAssetsLastThemeSummary;
static BOOL SaoqiangWCAssetsThemeCancelRequested;
static BOOL SaoqiangWCAssetsThemeRequestPending;
// 微信主题资源是延迟加载的：刚进入主题时 ThemeBox 清单可能还没建立，首次导出会拿到空清单。
// 这里记录自动重试次数——空结果时内部自动重跑，用户点一次即可完成整包，无需手动点第二次。
static NSUInteger SaoqiangWCAssetsThemeEmptyRetries = 0;
static BOOL SaoqiangWCAssetsThemeRetrying = NO;
static BOOL SaoqiangWCAssetsThemeAvailable(NSDictionary *summary) {
    return ![summary[@"cancelled"] boolValue] && ![summary[@"busy"] boolValue] &&
        ([summary[@"available"] boolValue] || [summary[@"written"] unsignedIntegerValue] > 0);
}
static BOOL SaoqiangWCAssetsThemeComplete(NSDictionary *summary) {
    return [summary[@"complete"] boolValue] && ![summary[@"cancelled"] boolValue] && ![summary[@"busy"] boolValue];
}
static NSString *SaoqiangWCAssetsThemeReceipt(NSDictionary *summary) {
    BOOL complete = SaoqiangWCAssetsThemeComplete(summary);
    NSString *coverage = complete ? @"此次清单已全部导出" : @"可先保存已导出的文件，未导出项目和原因见_export-info";
    NSString *diagnostic = [summary[@"diagnostic"] length] ? [NSString stringWithFormat:@"\n提示：%@", summary[@"diagnostic"]] : @"";
    return [NSString stringWithFormat:@"%@\n本次发现 %@ · 已导出 %@ · 未取到 %@ · 读取/写入失败 %@ · 重名已保留 %@ · 格式提示 %@\n来源 %@ · 数据 %@\n范围：%@\n原始文件平铺保留原名；重名保存在 _duplicates/编号/，可自行整理。\n清单与原因：_export-info/manifest.json、_export-info/issues.txt%@\n%@", summary[@"themeName"] ?: @"当前主题", summary[@"expected"] ?: @"未知", summary[@"written"] ?: @0, summary[@"missing"] ?: @0, summary[@"failed"] ?: @0, summary[@"conflicts"] ?: @0, summary[@"unsupported"] ?: @0, summary[@"provider"] ?: @"未知", summary[@"sourceMode"] ?: @"未知", summary[@"scope"] ?: @"当前加载器已提供的资源清单；未暴露资源及其他引擎覆盖情况未知", diagnostic, coverage];
}

// 0.5: page capture only; the Store owns capture policy and export filenames.
static __weak UIViewController *SaoqiangWCAssetsPresentedController;
// Non-zero while one of our controllers is on screen. This is a plain counter so
// the per-image-load path (SaoqiangWCAssetsOwnUIActive is called for every hook)
// does not pay for two weak loads. It only gates the expensive check; the weak
// references below still decide the answer.
static volatile int SaoqiangWCAssetsOwnUIVisible;
void SaoqiangWCAssetsNoteOwnUI(BOOL visible) {
    if (visible) __atomic_add_fetch(&SaoqiangWCAssetsOwnUIVisible, 1, __ATOMIC_RELAXED);
    else if (__atomic_load_n(&SaoqiangWCAssetsOwnUIVisible, __ATOMIC_RELAXED) > 0)
        __atomic_sub_fetch(&SaoqiangWCAssetsOwnUIVisible, 1, __ATOMIC_RELAXED);
}
BOOL SaoqiangWCAssetsOwnUIActive(void) {
    if (!__atomic_load_n(&SaoqiangWCAssetsOwnUIVisible, __ATOMIC_RELAXED)) return NO;
    return NSThread.isMainThread && (SaoqiangWCAssetsPresentedController.presentingViewController != nil ||
        SaoqiangWCAssetsPresentedController.isBeingPresented || SaoqiangWCAssetsInspectorUIActive());
}

// The master switch. Injected builds start off; the UI harness starts on so the
// existing export/capture checks keep exercising the full path. The value is a
// plain relaxed atomic so a hook pays one load and never touches a lock or a
// defaults object while the user is scrolling.
#ifdef SAOQIANG_WCASSETS_TESTING
static BOOL SaoqiangWCAssetsMasterValue = YES;
#else
static BOOL SaoqiangWCAssetsMasterValue = NO;
#endif
static NSString * const SaoqiangWCAssetsMasterKey = @"SaoqiangWCAssets.master.v1";
static BOOL SaoqiangWCAssetsIconValue = YES;
static BOOL SaoqiangWCAssetsThemeValue = YES;
// The 开始抓取 session is deliberately not persisted: a fresh launch must not
// resume capture just because the feature switch survived the upgrade. The
// test harness starts with it on so the launch-time naming checks can exercise
// the full path; the harness turns it off again before the layout screenshots.
#ifdef SAOQIANG_WCASSETS_TESTING
static BOOL SaoqiangWCAssetsIconCapturingValue = YES;
#else
static BOOL SaoqiangWCAssetsIconCapturingValue = NO;
#endif
static NSString * const SaoqiangWCAssetsIconKey = @"SaoqiangWCAssets.icon.v1";
static NSString * const SaoqiangWCAssetsThemeKey = @"SaoqiangWCAssets.theme.v1";
BOOL SaoqiangWCAssetsMasterEnabled(void) {
    return __atomic_load_n(&SaoqiangWCAssetsMasterValue, __ATOMIC_RELAXED) ? YES : NO;
}
void SaoqiangWCAssetsMasterLoad(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id savedMaster = [defaults objectForKey:SaoqiangWCAssetsMasterKey];
    BOOL master = savedMaster ? [savedMaster boolValue] : __atomic_load_n(&SaoqiangWCAssetsMasterValue, __ATOMIC_RELAXED);
    __atomic_store_n(&SaoqiangWCAssetsMasterValue, master ? YES : NO, __ATOMIC_RELAXED);
    id savedIcon = [defaults objectForKey:SaoqiangWCAssetsIconKey];
    if (savedIcon) __atomic_store_n(&SaoqiangWCAssetsIconValue, [savedIcon boolValue] ? YES : NO, __ATOMIC_RELAXED);
    id savedTheme = [defaults objectForKey:SaoqiangWCAssetsThemeKey];
    if (savedTheme) __atomic_store_n(&SaoqiangWCAssetsThemeValue, [savedTheme boolValue] ? YES : NO, __ATOMIC_RELAXED);
}
static void SaoqiangWCAssetsSyncCapture(void);
static void SaoqiangWCAssetsStoreFlag(BOOL *slot, NSString *key, BOOL enabled) {
    enabled = enabled ? YES : NO;
    BOOL previous = __atomic_exchange_n(slot, enabled, __ATOMIC_RELAXED);
    if (previous != enabled) [NSUserDefaults.standardUserDefaults setBool:enabled forKey:key];
}
// 图标抓取只由「开始抓取」会话决定：面板已取消图标功能开关，
// 点开始抓取即生效。保留 enabled 函数仅供持久化/测试兼容，不再参与门控。
BOOL SaoqiangWCAssetsIconCaptureEnabled(void) { return __atomic_load_n(&SaoqiangWCAssetsIconValue, __ATOMIC_RELAXED) ? YES : NO; }
BOOL SaoqiangWCAssetsIconCapturing(void) { return __atomic_load_n(&SaoqiangWCAssetsIconCapturingValue, __ATOMIC_RELAXED) ? YES : NO; }
BOOL SaoqiangWCAssetsIconCaptureActive(void) { return SaoqiangWCAssetsIconCapturing(); }
void SaoqiangWCAssetsSetIconCapturing(BOOL capturing) {
    capturing = capturing ? YES : NO;
    BOOL previous = __atomic_exchange_n(&SaoqiangWCAssetsIconCapturingValue, capturing, __ATOMIC_RELAXED);
    if (previous != capturing) SaoqiangWCAssetsSyncCapture();
}
BOOL SaoqiangWCAssetsThemeCaptureEnabled(void) { return __atomic_load_n(&SaoqiangWCAssetsThemeValue, __ATOMIC_RELAXED) ? YES : NO; }
void SaoqiangWCAssetsSetIconCaptureEnabled(BOOL enabled) {
    SaoqiangWCAssetsStoreFlag(&SaoqiangWCAssetsIconValue, SaoqiangWCAssetsIconKey, enabled);
    if (!enabled) __atomic_store_n(&SaoqiangWCAssetsIconCapturingValue, NO, __ATOMIC_RELAXED);
    SaoqiangWCAssetsSyncCapture();
}
void SaoqiangWCAssetsSetThemeCaptureEnabled(BOOL enabled) {
    SaoqiangWCAssetsStoreFlag(&SaoqiangWCAssetsThemeValue, SaoqiangWCAssetsThemeKey, enabled);
    SaoqiangWCAssetsSyncCapture();
}
void SaoqiangWCAssetsSetMasterEnabled(BOOL enabled) {
    SaoqiangWCAssetsStoreFlag(&SaoqiangWCAssetsMasterValue, SaoqiangWCAssetsMasterKey, enabled);
    if (!enabled) __atomic_store_n(&SaoqiangWCAssetsIconCapturingValue, NO, __ATOMIC_RELAXED);
    SaoqiangWCAssetsSyncCapture();
}
// The store flag mirrors the switches so existing capture/export code keeps
// working unchanged; turning everything off stops new records without clearing
// anything already collected.
static void SaoqiangWCAssetsSyncCapture(void) {
    BOOL on = SaoqiangWCAssetsMasterEnabled() &&
        (SaoqiangWCAssetsIconCaptureActive() || SaoqiangWCAssetsThemeCaptureEnabled());
    SaoqiangWCAssetsStore *store = [SaoqiangWCAssetsStore SaoqiangWCAssetsShared];
    if ([store SaoqiangWCAssetsEnabled] != on) [store SaoqiangWCAssetsSetEnabled:on];
}
static UIColor *SaoqiangWCAssetsCanvas(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.10 alpha:1] : [UIColor colorWithRed:0.925 green:0.922 blue:0.945 alpha:1];
    }];
}
static UIFont *SaoqiangWCAssetsFont(CGFloat size, UIFontWeight weight) {
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:size weight:weight] maximumPointSize:size * 1.15];
}
static UILabel *SaoqiangWCAssetsLabel(CGFloat size, UIFontWeight weight) {
    UILabel *label = [UILabel new]; label.font = SaoqiangWCAssetsFont(size, weight);
    label.adjustsFontForContentSizeCategory = YES; label.numberOfLines = 1; return label;
}
static UIImage *SaoqiangWCAssetsSymbol(NSString *name) {
    SaoqiangWCAssetsPushSuppression(); UIImage *image = nil;
    @try { image = [UIImage systemImageNamed:name]; if (image) SaoqiangWCAssetsMarkOwnImage(image); }
    @finally { SaoqiangWCAssetsPopSuppression(); }
    return image;
}
@interface SaoqiangWCAssetsPaddedButton : UIButton
@property(nonatomic) UIEdgeInsets SaoqiangWCAssetsPadding;
@end
@implementation SaoqiangWCAssetsPaddedButton
- (CGRect)contentRectForBounds:(CGRect)bounds { return UIEdgeInsetsInsetRect([super contentRectForBounds:bounds], self.SaoqiangWCAssetsPadding); }
- (CGSize)intrinsicContentSize {
    CGSize size = [super intrinsicContentSize]; size.width += self.SaoqiangWCAssetsPadding.left + self.SaoqiangWCAssetsPadding.right;
    size.height += self.SaoqiangWCAssetsPadding.top + self.SaoqiangWCAssetsPadding.bottom; return size;
}
- (void)setSaoqiangWCAssetsPadding:(UIEdgeInsets)padding { _SaoqiangWCAssetsPadding = padding; [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; }
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous]; if (self.layer.borderWidth) self.layer.borderColor = UIColor.separatorColor.CGColor;
}
@end
static SaoqiangWCAssetsPaddedButton *SaoqiangWCAssetsButton(NSString *title, id target, SEL action) {
    SaoqiangWCAssetsPaddedButton *button = [SaoqiangWCAssetsPaddedButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal]; [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    button.titleLabel.font = SaoqiangWCAssetsFont(13, UIFontWeightMedium); button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.SaoqiangWCAssetsPadding = UIEdgeInsetsMake(8, 10, 8, 10); button.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    button.layer.cornerRadius = 20; button.layer.borderWidth = 0.5; button.layer.borderColor = UIColor.separatorColor.CGColor;
    if (action) [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    SaoqiangWCAssetsMarkOwnView(button); return button;
}
static BOOL SaoqiangWCAssetsHasOriginalName(SaoqiangWCAssetsRecord *record) {
    NSString *name = [record.name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return name.length && ![name containsString:@"无原名"] && ![name containsString:@"无原始资源名"] && ![name containsString:@"未命名"];
}
static BOOL SaoqiangWCAssetsIsSVG(SaoqiangWCAssetsRecord *record) {
    // svgResource describes the renderer; kind describes the bytes we actually have.
    return [record.kind.uppercaseString isEqualToString:@"SVG"];
}
static BOOL SaoqiangWCAssetsIsNative(SaoqiangWCAssetsRecord *record) {
    if (record.svgResource || SaoqiangWCAssetsIsSVG(record) || [record.name.pathExtension.lowercaseString isEqualToString:@"svg"] || !SaoqiangWCAssetsHasOriginalName(record)) return NO;
    NSString *source = [record.source componentsSeparatedByString:@" · "].firstObject;
    return [source containsString:@"UIImage imageNamed:"] || [source containsString:@"UIImage imageWithContentsOfFile:"] || [source containsString:@"UIImage initWithContentsOfFile:"];
}
static BOOL SaoqiangWCAssetsIsCurrent(SaoqiangWCAssetsRecord *record, NSString *runtimeID) {
    return runtimeID.length && [record.origin isEqualToString:@"runtime"] && [record.sessionID isEqualToString:runtimeID];
}
static void SaoqiangWCAssetsAfterDismiss(UIViewController *controller, dispatch_block_t action) {
    if (controller.isBeingDismissed && controller.transitionCoordinator) {
        [controller.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) { dispatch_async(dispatch_get_main_queue(), action); }];
    } else if (controller.presentingViewController) [controller dismissViewControllerAnimated:YES completion:action];
    else dispatch_async(dispatch_get_main_queue(), action);
}
typedef NS_ENUM(NSInteger, SaoqiangWCAssetsFilterKind) {
    SaoqiangWCAssetsFilterCurrent, SaoqiangWCAssetsFilterSVG, SaoqiangWCAssetsFilterPNG,
    SaoqiangWCAssetsFilterNative, SaoqiangWCAssetsFilterTools
};

// A UISwitch-shaped control drawn from layers. The injected target already
// carries a large UIKit-hooking tweak, and a plain [UISwitch new] renders at
// zero size there even with explicit constraints. This keeps the exact native
// look (green/grey track, white knob) without going through that class.
@interface SaoqiangWCAssetsToggle : UIControl
@property(nonatomic) BOOL on;
@end
@implementation SaoqiangWCAssetsToggle {
    CAShapeLayer *_track;
    CAShapeLayer *_knob;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = UIColor.clearColor;
        _track = [CAShapeLayer layer];
        _track.fillColor = UIColor.systemGreenColor.CGColor;
        [self.layer addSublayer:_track];
        _knob = [CAShapeLayer layer];
        _knob.fillColor = UIColor.whiteColor.CGColor;
        _knob.shadowColor = UIColor.blackColor.CGColor;
        _knob.shadowOpacity = 0.18; _knob.shadowRadius = 1.5; _knob.shadowOffset = CGSizeMake(0, 1);
        [self.layer addSublayer:_knob];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(SaoqiangWCAssetsTap:)];
        [self addGestureRecognizer:tap];
        self.exclusiveTouch = YES;
        [self SaoqiangWCAssetsLayout];
    }
    return self;
}
- (CGSize)intrinsicContentSize { return CGSizeMake(51, 31); }
- (void)setOn:(BOOL)on {
    _on = on;
    [self SaoqiangWCAssetsLayout];
}
- (void)SaoqiangWCAssetsTap:(UITapGestureRecognizer *)tap {
    if (tap.state != UIGestureRecognizerStateEnded) return;
    self.on = !self.on;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (void)SaoqiangWCAssetsLayout {
    CGRect b = self.bounds;
    if (b.size.width < 1 || b.size.height < 1) return;
    CGFloat h = b.size.height, r = h / 2;
    UIBezierPath *track = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:r];
    _track.path = track.CGPath;
    _track.fillColor = (self.on ? UIColor.systemGreenColor : UIColor.systemGray4Color).CGColor;
    CGFloat d = h - 4;
    CGFloat x = self.on ? CGRectGetMaxX(b) - d - 2 : CGRectGetMinX(b) + 2;
    _knob.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(x, 2, d, d)].CGPath;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    [self SaoqiangWCAssetsLayout];
}
- (void)tintColorDidChange { [super tintColorDidChange]; [self SaoqiangWCAssetsLayout]; }
@end

@interface SaoqiangWCAssetsCell : UITableViewCell <UIContextMenuInteractionDelegate>
@property(nonatomic,strong) UIView *SaoqiangWCAssetsCard;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsPreview;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsName;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsDetail;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsCopy;
@property(nonatomic,copy) dispatch_block_t SaoqiangWCAssetsCopyAction;
@property(nonatomic,copy) dispatch_block_t SaoqiangWCAssetsPreviewAction;
@property(nonatomic,copy) void (^SaoqiangWCAssetsContextAction)(BOOL);
@end
@implementation SaoqiangWCAssetsCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:style reuseIdentifier:identifier])) {
        SaoqiangWCAssetsMarkOwnView(self); self.backgroundColor = UIColor.clearColor; self.selectionStyle = UITableViewCellSelectionStyleNone;
        UIView *card = [UIView new]; card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; card.layer.cornerRadius = 16;
        card.translatesAutoresizingMaskIntoConstraints = NO; self.SaoqiangWCAssetsCard = card; [self.contentView addSubview:card];
        SaoqiangWCAssetsPaddedButton *preview = [SaoqiangWCAssetsPaddedButton buttonWithType:UIButtonTypeCustom];
        preview.backgroundColor = SaoqiangWCAssetsCanvas(); preview.layer.cornerRadius = 9; preview.clipsToBounds = YES;
        preview.imageView.contentMode = UIViewContentModeScaleAspectFit; preview.SaoqiangWCAssetsPadding = UIEdgeInsetsMake(3, 3, 3, 3);
        [preview addTarget:self action:@selector(SaoqiangWCAssetsShowPreview) forControlEvents:UIControlEventTouchUpInside];
        [preview addInteraction:[[UIContextMenuInteraction alloc] initWithDelegate:self]]; self.SaoqiangWCAssetsPreview = preview;
        self.SaoqiangWCAssetsName = SaoqiangWCAssetsLabel(13, UIFontWeightSemibold); self.SaoqiangWCAssetsName.lineBreakMode = NSLineBreakByTruncatingMiddle;
        self.SaoqiangWCAssetsDetail = SaoqiangWCAssetsLabel(10, UIFontWeightRegular); self.SaoqiangWCAssetsDetail.textColor = UIColor.secondaryLabelColor;
        UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[self.SaoqiangWCAssetsName, self.SaoqiangWCAssetsDetail]];
        text.axis = UILayoutConstraintAxisVertical; text.spacing = 4;
        [text setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        self.SaoqiangWCAssetsCopy = SaoqiangWCAssetsButton(@"复制", self, @selector(SaoqiangWCAssetsCopyName));
        for (UIView *view in @[preview, text, self.SaoqiangWCAssetsCopy]) { view.translatesAutoresizingMaskIntoConstraints = NO; [card addSubview:view]; }
        UIButton *copy = self.SaoqiangWCAssetsCopy;
        [NSLayoutConstraint activateConstraints:@[
            [card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12], [card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
            [card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6], [card.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
            [preview.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12], [preview.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
            [preview.widthAnchor constraintEqualToConstant:40], [preview.heightAnchor constraintEqualToConstant:40],
            [text.leadingAnchor constraintEqualToAnchor:preview.trailingAnchor constant:10], [text.trailingAnchor constraintEqualToAnchor:copy.leadingAnchor constant:-8], [text.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
            [copy.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12], [copy.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
            [copy.widthAnchor constraintEqualToConstant:56], [copy.heightAnchor constraintEqualToConstant:40]
        ]];
    }
    return self;
}
- (void)SaoqiangWCAssetsCopyName { if (self.SaoqiangWCAssetsCopyAction) self.SaoqiangWCAssetsCopyAction(); }
- (void)SaoqiangWCAssetsShowPreview { if (self.SaoqiangWCAssetsPreviewAction) self.SaoqiangWCAssetsPreviewAction(); }
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location {
    dispatch_block_t preview = self.SaoqiangWCAssetsPreviewAction;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        UIAction *save = [UIAction actionWithTitle:@"单项保存…" image:SaoqiangWCAssetsSymbol(@"square.and.arrow.down") identifier:nil handler:^(UIAction *action) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (preview) preview(); });
        }];
        return [UIMenu menuWithTitle:@"" children:@[save]];
    }];
}
- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willDisplayMenuForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator {
    if (self.SaoqiangWCAssetsContextAction) self.SaoqiangWCAssetsContextAction(YES);
}
- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willEndForConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionAnimating>)animator {
    void (^context)(BOOL) = self.SaoqiangWCAssetsContextAction;
    dispatch_block_t end = ^{ if (context) context(NO); };
    if (animator) [animator addCompletion:end]; else end();
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated]; self.SaoqiangWCAssetsCard.layer.borderWidth = selected ? 1.5 : 0;
    self.SaoqiangWCAssetsCard.layer.borderColor = UIColor.labelColor.CGColor;
    self.accessibilityTraits = UIAccessibilityTraitButton | (selected ? UIAccessibilityTraitSelected : 0);
}
- (void)traitCollectionDidChange:(UITraitCollection *)previous { [super traitCollectionDidChange:previous]; [self setSelected:self.selected animated:NO]; }
- (void)prepareForReuse {
    [super prepareForReuse]; self.SaoqiangWCAssetsCopyAction = nil; self.SaoqiangWCAssetsPreviewAction = nil; self.SaoqiangWCAssetsContextAction = nil;
    [self.SaoqiangWCAssetsPreview setImage:nil forState:UIControlStateNormal];
}
@end

#pragma mark - 手势快捷入口的底部卡片（0.11.40）

// The two/three-finger shortcut used to open the panel full screen, covering
// WeChat completely. It now opens as a bottom card covering 3/5 of the screen;
// dragging its header up grows it to 4.5/5 (a strip of WeChat stays visible),
// dragging back down returns it to 3/5. The plugin-hub entry still pushes the
// panel the old way, so nothing changes for users who open it from there.
static const CGFloat SaoqiangWCAssetsSheetCollapsedFraction = 0.6;   // 3/5 屏
static const CGFloat SaoqiangWCAssetsSheetExpandedFraction = 0.9;    // 4.5/5 屏
static const CGFloat SaoqiangWCAssetsSheetGrabberHeight = 18;

@interface SaoqiangWCAssetsSheetHost : UIViewController <UIGestureRecognizerDelegate>
@property(nonatomic,strong,readonly) UINavigationController *SaoqiangWCAssetsNav;
@property(nonatomic,strong,readonly) UIView *SaoqiangWCAssetsCard;
- (instancetype)initWithNavigation:(UINavigationController *)nav;
- (BOOL)SaoqiangWCAssetsExpanded;
- (void)SaoqiangWCAssetsSetExpanded:(BOOL)expanded animated:(BOOL)animated;
@end

@implementation SaoqiangWCAssetsSheetHost {
    UIView *_SaoqiangWCAssetsDim;
    UIView *_SaoqiangWCAssetsCard;
    UINavigationController *_SaoqiangWCAssetsNav;
    NSLayoutConstraint *_SaoqiangWCAssetsHeight;
    CGFloat _SaoqiangWCAssetsStartHeight;
    BOOL _SaoqiangWCAssetsExpanded;
    BOOL _SaoqiangWCAssetsDragging;
}

- (instancetype)initWithNavigation:(UINavigationController *)nav {
    self = [super initWithNibName:nil bundle:nil];
    if (self) _SaoqiangWCAssetsNav = nav;
    return self;
}
- (UINavigationController *)SaoqiangWCAssetsNav { return _SaoqiangWCAssetsNav; }
- (UIView *)SaoqiangWCAssetsCard { return _SaoqiangWCAssetsCard; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    SaoqiangWCAssetsMarkOwnView(self.view);

    UIView *dim = [UIView new];
    _SaoqiangWCAssetsDim = dim;
    dim.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.18];
    dim.translatesAutoresizingMaskIntoConstraints = NO;
    SaoqiangWCAssetsMarkOwnView(dim);
    [self.view addSubview:dim];
    [dim addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(SaoqiangWCAssetsDimTapped)]];

    UIView *card = [UIView new];
    _SaoqiangWCAssetsCard = card;
    card.backgroundColor = SaoqiangWCAssetsCanvas();
    card.layer.cornerRadius = 22;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    card.clipsToBounds = YES;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    SaoqiangWCAssetsMarkOwnView(card);
    [self.view addSubview:card];

    // A sheet-style grabber so the drag target is visible, the same affordance
    // iOS uses for its own resizeable sheets.
    UIView *grabberArea = [UIView new];
    grabberArea.backgroundColor = UIColor.clearColor;
    grabberArea.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:grabberArea];
    UIView *grabber = [UIView new];
    grabber.backgroundColor = [UIColor.secondaryLabelColor colorWithAlphaComponent:0.35];
    grabber.layer.cornerRadius = 2.5;
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    [grabberArea addSubview:grabber];

    _SaoqiangWCAssetsHeight = [card.heightAnchor constraintEqualToConstant:0];
    [NSLayoutConstraint activateConstraints:@[
        [dim.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [dim.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [dim.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [dim.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        _SaoqiangWCAssetsHeight,
        [grabberArea.topAnchor constraintEqualToAnchor:card.topAnchor],
        [grabberArea.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [grabberArea.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [grabberArea.heightAnchor constraintEqualToConstant:SaoqiangWCAssetsSheetGrabberHeight],
        [grabber.centerXAnchor constraintEqualToAnchor:grabberArea.centerXAnchor],
        [grabber.centerYAnchor constraintEqualToAnchor:grabberArea.centerYAnchor],
        [grabber.widthAnchor constraintEqualToConstant:36],
        [grabber.heightAnchor constraintEqualToConstant:5]
    ]];

    // The panel keeps running inside its own navigation controller; hosting it
    // as a child leaves the ‹ chevron and the page transitions untouched.
    [self addChildViewController:_SaoqiangWCAssetsNav];
    UIView *navView = _SaoqiangWCAssetsNav.view;
    navView.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:navView];
    [NSLayoutConstraint activateConstraints:@[
        [navView.topAnchor constraintEqualToAnchor:grabberArea.bottomAnchor],
        [navView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [navView.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [navView.bottomAnchor constraintEqualToAnchor:card.bottomAnchor]
    ]];
    [_SaoqiangWCAssetsNav didMoveToParentViewController:self];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(SaoqiangWCAssetsPanChanged:)];
    pan.delegate = self;
    [card addGestureRecognizer:pan];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    if (_SaoqiangWCAssetsDragging) return;
    CGFloat height = CGRectGetHeight(self.view.bounds);
    if (height <= 0) return;
    CGFloat fraction = _SaoqiangWCAssetsExpanded ? SaoqiangWCAssetsSheetExpandedFraction : SaoqiangWCAssetsSheetCollapsedFraction;
    _SaoqiangWCAssetsHeight.constant = floor(height * fraction);
}

- (BOOL)SaoqiangWCAssetsExpanded { return _SaoqiangWCAssetsExpanded; }

- (void)SaoqiangWCAssetsSetExpanded:(BOOL)expanded animated:(BOOL)animated {
    _SaoqiangWCAssetsExpanded = expanded;
    CGFloat height = CGRectGetHeight(self.view.bounds);
    if (height > 0) {
        CGFloat fraction = expanded ? SaoqiangWCAssetsSheetExpandedFraction : SaoqiangWCAssetsSheetCollapsedFraction;
        _SaoqiangWCAssetsHeight.constant = floor(height * fraction);
    }
    _SaoqiangWCAssetsDim.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:expanded ? 0.42 : 0.18];
    if (!animated) { [self.view layoutIfNeeded]; return; }
    [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0.12
                        options:UIViewAnimationOptionCurveEaseOut animations:^{ [self.view layoutIfNeeded]; } completion:nil];
}
#ifdef SAOQIANG_WCASSETS_TESTING
- (void)SaoqiangWCAssetsExpandForTesting {
    [self SaoqiangWCAssetsSetExpanded:YES animated:NO];
    [self.view layoutIfNeeded];
}
#endif

// Only vertical drags are ours; anything that lands in a scroll view keeps
// scrolling. The header strip (grabber + navigation bar) always resizes.
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (![gestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]) return NO;
    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
    CGPoint velocity = [pan velocityInView:_SaoqiangWCAssetsCard];
    CGPoint translation = [pan translationInView:_SaoqiangWCAssetsCard];
    CGFloat vertical = fabs(velocity.y) > 1 ? velocity.y : translation.y;
    CGFloat horizontal = fabs(velocity.x) > 1 ? velocity.x : translation.x;
    if (fabs(vertical) <= fabs(horizontal)) return NO;
    CGPoint point = [pan locationInView:_SaoqiangWCAssetsCard];
    if (point.y <= SaoqiangWCAssetsSheetGrabberHeight + 52) return YES;
    UIView *hit = [_SaoqiangWCAssetsCard hitTest:point withEvent:nil];
    for (UIView *view = hit; view && view != _SaoqiangWCAssetsCard; view = view.superview)
        if ([view isKindOfClass:UIScrollView.class]) return NO;
    return YES;
}

- (void)SaoqiangWCAssetsPanChanged:(UIPanGestureRecognizer *)pan {
    CGFloat height = CGRectGetHeight(self.view.bounds);
    if (height <= 0) return;
    CGFloat minimum = floor(height * SaoqiangWCAssetsSheetCollapsedFraction);
    CGFloat maximum = floor(height * SaoqiangWCAssetsSheetExpandedFraction);
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
            _SaoqiangWCAssetsStartHeight = _SaoqiangWCAssetsHeight.constant > 0 ? _SaoqiangWCAssetsHeight.constant : minimum;
            _SaoqiangWCAssetsDragging = YES;
            break;
        case UIGestureRecognizerStateChanged: {
            CGFloat moved = [pan translationInView:self.view].y;
            CGFloat current = MIN(maximum, MAX(minimum, _SaoqiangWCAssetsStartHeight - moved));
            _SaoqiangWCAssetsHeight.constant = current;
            CGFloat progress = (maximum > minimum) ? (current - minimum) / (maximum - minimum) : 0;
            _SaoqiangWCAssetsDim.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.18 + 0.24 * progress];
            [self.view layoutIfNeeded];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            _SaoqiangWCAssetsDragging = NO;
            CGFloat velocity = [pan velocityInView:self.view].y;
            CGFloat current = _SaoqiangWCAssetsHeight.constant;
            BOOL expand;
            if (velocity < -300) expand = YES;
            else if (velocity > 300) expand = NO;
            else expand = current - minimum >= (maximum - minimum) / 2.0;
            [self SaoqiangWCAssetsSetExpanded:expand animated:YES];
            break;
        }
        default: break;
    }
}

- (void)SaoqiangWCAssetsDimTapped {
    if (_SaoqiangWCAssetsExpanded) { [self SaoqiangWCAssetsSetExpanded:NO animated:YES]; return; }
    UIViewController *panel = _SaoqiangWCAssetsNav.viewControllers.firstObject;
    [self dismissViewControllerAnimated:YES completion:^{
        if (SaoqiangWCAssetsPresentedController == panel) SaoqiangWCAssetsPresentedController = nil;
    }];
}
@end

@interface SaoqiangWCAssetsController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate, UIGestureRecognizerDelegate>
@property(nonatomic,weak) SaoqiangWCAssetsSheetHost *SaoqiangWCAssetsSheet;
@property(nonatomic,strong) UIView *SaoqiangWCAssetsHomeView;
@property(nonatomic,strong) UIView *SaoqiangWCAssetsIconPage;
@property(nonatomic,strong) UIView *SaoqiangWCAssetsThemePage;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsIconEntry;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsThemeEntry;
@property(nonatomic) NSInteger SaoqiangWCAssetsPage;
@property(nonatomic,strong) UITableView *SaoqiangWCAssetsTable;
@property(nonatomic,strong) UISearchBar *SaoqiangWCAssetsSearch;
@property(nonatomic,strong) UISegmentedControl *SaoqiangWCAssetsFilter;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsStartButton;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsHomeButton;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsStartHint;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsSummary;
@property(nonatomic,strong) SaoqiangWCAssetsToggle *SaoqiangWCAssetsMasterSwitch;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsThemeTabButton;
@property(nonatomic) BOOL SaoqiangWCAssetsThemeTab;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsEmpty;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsScopeLabel;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsFeedback;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsClearButton;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsSelectButton;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsFolderButton;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsThemeButton;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsThemeProgress;
@property(nonatomic,strong) UIScrollView *SaoqiangWCAssetsToolsScroll;
@property(nonatomic,strong) NSArray<SaoqiangWCAssetsRecord *> *SaoqiangWCAssetsRows;
@property(nonatomic,strong) NSArray<NSString *> *SaoqiangWCAssetsIdentities;
@property(nonatomic,strong) NSMutableDictionary<NSString *, SaoqiangWCAssetsRecord *> *SaoqiangWCAssetsSelected;
@property(nonatomic) SaoqiangWCAssetsFilterKind SaoqiangWCAssetsLastListFilter;
@property(nonatomic,strong) NSTimer *SaoqiangWCAssetsTimer;
@property(nonatomic) BOOL SaoqiangWCAssetsBusy;
@property(nonatomic) BOOL SaoqiangWCAssetsOwnUICounted;
@property(nonatomic) BOOL SaoqiangWCAssetsPendingRefresh;
@property(nonatomic) BOOL SaoqiangWCAssetsPendingReset;
// 0.11.44: what the rows on screen were built from. A tick that finds the same
// inputs reuses them instead of walking the whole record list again.
@property(nonatomic) NSUInteger SaoqiangWCAssetsBuiltRevision;
@property(nonatomic,copy) NSString *SaoqiangWCAssetsBuiltQuery;
@property(nonatomic) SaoqiangWCAssetsFilterKind SaoqiangWCAssetsBuiltFilter;
@property(nonatomic) BOOL SaoqiangWCAssetsBuiltTools;
@property(nonatomic) BOOL SaoqiangWCAssetsBuiltValid;
@property(nonatomic) BOOL SaoqiangWCAssetsContextOpen;
@property(nonatomic) NSUInteger SaoqiangWCAssetsCurrentCount;
@property(nonatomic) NSUInteger SaoqiangWCAssetsSVGCount;
@property(nonatomic) NSUInteger SaoqiangWCAssetsPNGCount;
@property(nonatomic) NSUInteger SaoqiangWCAssetsNativeCount;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsTotalValue;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsPNGValue;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsSVGValue;
@property(nonatomic,strong) UILabel *SaoqiangWCAssetsNativeValue;
@property(nonatomic) NSUInteger SaoqiangWCAssetsFeedbackGeneration;
@property(nonatomic,strong) NSDictionary *SaoqiangWCAssetsPendingExport;
@property(nonatomic,weak) id<UIGestureRecognizerDelegate> SaoqiangWCAssetsSavedPopDelegate;
@property(nonatomic,strong) UIScreenEdgePanGestureRecognizer *SaoqiangWCAssetsEdgePan;
@property(nonatomic) BOOL SaoqiangWCAssetsPopDelegateInstalled;
@property(nonatomic,strong) UIButton *SaoqiangWCAssetsFallbackBack;
@property(nonatomic) BOOL SaoqiangWCAssetsSkipPageAnimation;
// 0.11.41: the three page containers are pinned to the controller's own view
// with constants recomputed on every layout pass. Inside the draggable card the
// navigation controller lives in a child container, and its safe-area insets do
// not always include the bar there — pinning to the safe-area guide put the page
// titles underneath the bar. These two constraints always resolve to the bar's
// bottom edge and to the real bottom inset.
@property(nonatomic,strong) NSLayoutConstraint *SaoqiangWCAssetsPagesTop;
@property(nonatomic,strong) NSLayoutConstraint *SaoqiangWCAssetsPagesBottom;
// 0.11.42: required gap to the navigation bar's own bottom edge.
@property(nonatomic,strong) UIView *SaoqiangWCAssetsPagesHost;
@property(nonatomic,strong) NSLayoutConstraint *SaoqiangWCAssetsPagesBarGap;
- (void)SaoqiangWCAssetsRefresh:(BOOL)reset;
- (void)SaoqiangWCAssetsPreviewRecord:(SaoqiangWCAssetsRecord *)record;
- (void)SaoqiangWCAssetsUpdateSelection;
// Declared for the C helpers below (present path), which call it on a typed
// receiver from outside the @implementation.
- (void)SaoqiangWCAssetsShowPage:(NSInteger)page;
@end
static void SaoqiangWCAssetsUnwindWeChatHome(UIViewController *anchor);

#pragma mark - 全局双指/三指长按（事件层实现）

// A UILongPressGestureRecognizer attached to the key window frequently loses
// the race against WeChat's own recognizers (and the key window is often not
// resolvable when the dylib loads). Hooking -[UIApplication sendEvent:] is far
// more reliable: it is the single entry point every touch on every screen
// passes through before any view or gesture sees it, so no host recognizer can
// swallow it. We only inspect the touch set -- we never consume or rewrite the
// event, and the original implementation always runs first.
static void (*SaoqiangWCAssetsSendEventOriginal)(id, SEL, UIEvent *);
static NSUInteger SaoqiangWCAssetsTouchCount;
static CGPoint SaoqiangWCAssetsTouchOrigin;
static BOOL SaoqiangWCAssetsTouchInvalid;
static BOOL SaoqiangWCAssetsTouchFired;

static void SaoqiangWCAssetsResetTouchTracking(void) {
    SaoqiangWCAssetsTouchCount = 0;
    SaoqiangWCAssetsTouchOrigin = CGPointZero;
    SaoqiangWCAssetsTouchInvalid = NO;
    SaoqiangWCAssetsTouchFired = NO;
}
static void SaoqiangWCAssetsInspectTouches(UIEvent *event) {
    if (event.type != UIEventTypeTouches) return;
    NSSet<UITouch *> *touches = event.allTouches;
    if (!touches.count) return;
    NSUInteger active = 0;
    CGPoint sum = CGPointZero;
    for (UITouch *touch in touches) {
        UITouchPhase phase = touch.phase;
        if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) continue;
        active++;
        CGPoint point = [touch locationInView:nil];
        sum.x += point.x; sum.y += point.y;
    }
    if (active == 0 || active != touches.count) {
        // Any finger lift/cancel ends the current hold.
        SaoqiangWCAssetsResetTouchTracking();
        if (active == 0) return;
    }
    if (active < 2 || active > 3) {
        SaoqiangWCAssetsTouchCount = active;
        SaoqiangWCAssetsTouchInvalid = YES;
        return;
    }
    if (active != SaoqiangWCAssetsTouchCount) {
        // Wait until touches are bound to a window, otherwise locationInView:nil
        // is meaningless and the movement check would misfire. The UIWindow
        // hook (also installed) will pick the sequence up one layer below.
        UITouch *sample = nil;
        for (UITouch *touch in touches) {
            if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) { sample = touch; break; }
        }
        if (!sample.window) return;
        // A new finger count starts a fresh hold window.
        SaoqiangWCAssetsTouchCount = active;
        SaoqiangWCAssetsTouchOrigin = CGPointMake(sum.x / active, sum.y / active);
        SaoqiangWCAssetsTouchInvalid = NO;
        SaoqiangWCAssetsTouchFired = NO;
        NSUInteger fingers = active;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // Stationary fingers stop generating events, so the hold must be
            // confirmed by a timer: still the same finger count, not moved,
            // not already fired.
            if (SaoqiangWCAssetsTouchCount != fingers || SaoqiangWCAssetsTouchInvalid ||
                SaoqiangWCAssetsTouchFired) return;
            SaoqiangWCAssetsTouchFired = YES;
            if (SaoqiangWCAssetsOwnUIActive()) return;
            if (fingers == 3) SaoqiangWCAssetsPresentThemePage();
            else SaoqiangWCAssetsPresentIconPage();
        });
        return;
    }
    if (SaoqiangWCAssetsTouchInvalid || SaoqiangWCAssetsTouchFired) return;
    CGPoint current = CGPointMake(sum.x / active, sum.y / active);
    CGFloat dx = current.x - SaoqiangWCAssetsTouchOrigin.x;
    CGFloat dy = current.y - SaoqiangWCAssetsTouchOrigin.y;
    if (dx * dx + dy * dy > 900.0) SaoqiangWCAssetsTouchInvalid = YES;
}
static void SaoqiangWCAssetsApplicationSendEvent(UIApplication *self, SEL _cmd, UIEvent *event) {
    if (SaoqiangWCAssetsSendEventOriginal) SaoqiangWCAssetsSendEventOriginal(self, _cmd, event);
    SaoqiangWCAssetsInspectTouches(event);
}
static void (*SaoqiangWCAssetsWindowSendEventOriginal)(id, SEL, UIEvent *);
static void SaoqiangWCAssetsWindowSendEvent(UIWindow *self, SEL _cmd, UIEvent *event) {
    if (SaoqiangWCAssetsWindowSendEventOriginal) SaoqiangWCAssetsWindowSendEventOriginal(self, _cmd, event);
    SaoqiangWCAssetsInspectTouches(event);
}
static void SaoqiangWCAssetsInstallGlobalPress(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Hook both entry points. UIApplication catches every event even if a
        // window subclass overrides sendEvent:; UIWindow is where touches are
        // bound to a window, so its coordinates are always valid. The detector
        // is idempotent per touch sequence, so seeing the event twice is fine.
        Class appClass = UIApplication.sharedApplication.class ?: UIApplication.class;
        Method appMethod = class_getInstanceMethod(appClass, @selector(sendEvent:));
        if (!appMethod) appMethod = class_getInstanceMethod(UIApplication.class, @selector(sendEvent:));
        if (appMethod) {
            SaoqiangWCAssetsSendEventOriginal = (void *)method_getImplementation(appMethod);
            method_setImplementation(appMethod, (IMP)SaoqiangWCAssetsApplicationSendEvent);
        }
        Method windowMethod = class_getInstanceMethod(UIWindow.class, @selector(sendEvent:));
        if (windowMethod) {
            SaoqiangWCAssetsWindowSendEventOriginal = (void *)method_getImplementation(windowMethod);
            method_setImplementation(windowMethod, (IMP)SaoqiangWCAssetsWindowSendEvent);
        }
        NSLog(@"[小扒手] 全局双指/三指长按已挂载（app=%@, window=%@）",
              appMethod ? NSStringFromClass(appClass) : @"nil",
              windowMethod ? @"UIWindow" : @"nil");
    });
}

@implementation SaoqiangWCAssetsController
- (UIButton *)SaoqiangWCAssetsEntryButton:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    button.titleLabel.font = SaoqiangWCAssetsFont(16, UIFontWeightRegular);
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentEdgeInsets = UIEdgeInsetsMake(12, 16, 12, 40);
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    SaoqiangWCAssetsMarkOwnView(button);
    // Plain text chevron: SF Symbols and custom controls are unreliable in the
    // injected target, while a UILabel always renders.
    UILabel *arrow = SaoqiangWCAssetsLabel(16, UIFontWeightRegular);
    arrow.text = @">";
    arrow.textColor = UIColor.tertiaryLabelColor;
    arrow.translatesAutoresizingMaskIntoConstraints = NO;
    arrow.userInteractionEnabled = NO;
    [button addSubview:arrow];
    [NSLayoutConstraint activateConstraints:@[
        [arrow.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-16],
        [arrow.centerYAnchor constraintEqualToAnchor:button.centerYAnchor]
    ]];
    return button;
}
- (UIButton *)SaoqiangWCAssetsBackButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:@"‹ 返回" forState:UIControlStateNormal];
    [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    button.titleLabel.font = SaoqiangWCAssetsFont(15, UIFontWeightRegular);
    [button addTarget:self action:@selector(SaoqiangWCAssetsBackTapped) forControlEvents:UIControlEventTouchUpInside];
    SaoqiangWCAssetsMarkOwnView(button);
    return button;
}
- (UIButton *)SaoqiangWCAssetsCloseButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setTitle:@"关闭" forState:UIControlStateNormal];
    [button setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    button.titleLabel.font = SaoqiangWCAssetsFont(15, UIFontWeightRegular);
    [button addTarget:self action:@selector(SaoqiangWCAssetsClose) forControlEvents:UIControlEventTouchUpInside];
    SaoqiangWCAssetsMarkOwnView(button);
    return button;
}
- (UIView *)SaoqiangWCAssetsPageView:(NSInteger)page {
    if (page == 1) return self.SaoqiangWCAssetsIconPage;
    if (page == 2) return self.SaoqiangWCAssetsThemePage;
    return self.SaoqiangWCAssetsHomeView;
}
- (void)SaoqiangWCAssetsShowPage:(NSInteger)page {
    NSInteger previous = self.SaoqiangWCAssetsPage;
    self.SaoqiangWCAssetsPage = page;
    // Home carries its own logo + title; sub-pages keep the host nav title.
    self.navigationItem.title = (page == 0) ? @"" : @"小扒手";

    UIView *from = [self SaoqiangWCAssetsPageView:previous];
    UIView *to = [self SaoqiangWCAssetsPageView:page];
    // 0.11.39: the gesture shortcut sets its page before the panel is presented.
    // There is nothing to slide between yet, and a transition here would make
    // the home page flash for as long as the presentation animation runs.
    BOOL animate = (from && to && from != to && !self.view.isHidden && !self.SaoqiangWCAssetsSkipPageAnimation);
    if (animate) self.view.userInteractionEnabled = NO;

    for (UIView *view in @[self.SaoqiangWCAssetsHomeView, self.SaoqiangWCAssetsIconPage, self.SaoqiangWCAssetsThemePage]) {
        if (view != to && view != (animate ? from : nil)) view.hidden = YES;
    }
    if (!animate) {
        to.hidden = NO;
    } else {
        to.hidden = NO;
        CGFloat width = CGRectGetWidth(self.view.bounds);
        BOOL forward = page > previous;
        to.transform = CGAffineTransformMakeTranslation(forward ? width : -width, 0);
        to.alpha = 0;
        from.transform = CGAffineTransformIdentity;
        from.alpha = 1;
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.95 initialSpringVelocity:0.08
                            options:UIViewAnimationOptionCurveEaseOut animations:^{
            to.transform = CGAffineTransformIdentity;
            to.alpha = 1;
            from.transform = CGAffineTransformMakeTranslation(forward ? -width * 0.22 : width * 0.22, 0);
            from.alpha = 0;
        } completion:^(BOOL finished) {
            (void)finished;
            from.hidden = YES;
            from.transform = CGAffineTransformIdentity;
            from.alpha = 1;
            to.transform = CGAffineTransformIdentity;
            to.alpha = 1;
            self.view.userInteractionEnabled = YES;
        }];
    }

    if (page == 1) {
        self.SaoqiangWCAssetsThemeTab = NO;
        [self SaoqiangWCAssetsRefresh:YES];
    } else if (page == 2) {
        self.SaoqiangWCAssetsThemeTab = YES;
        [self SaoqiangWCAssetsRefresh:NO];
        [self SaoqiangWCAssetsRefreshTheme];
    }
    [self.view endEditing:YES];
}
- (void)SaoqiangWCAssetsIconEntryTapped { [self SaoqiangWCAssetsShowPage:1]; }
- (void)SaoqiangWCAssetsThemeEntryTapped { [self SaoqiangWCAssetsShowPage:2]; }
- (void)SaoqiangWCAssetsBackTapped { [self SaoqiangWCAssetsShowPage:0]; }
// The host pushes this controller, so its system back arrow would pop straight
// to the WCRefine plugin hub. Use our own chevron to walk pages first: 图标/
// 主题 -> 小扒手首页, and only the homepage pops back to the host.
- (void)SaoqiangWCAssetsNavBackTapped {
    if (self.SaoqiangWCAssetsPage != 0) {
        [self SaoqiangWCAssetsShowPage:0];
        return;
    }
    [self.view endEditing:YES];
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    if (self.presentingViewController) {
        [[self SaoqiangWCAssetsDismissTarget] dismissViewControllerAnimated:YES completion:^{
            if (SaoqiangWCAssetsPresentedController == self) SaoqiangWCAssetsPresentedController = nil;
        }];
    }
}
// Safety net only: a navigation item cannot be drawn without a navigation bar.
// If this controller is ever shown without a navigation controller (a full
// screen panel with no ‹ and no way out), draw the chevron as a plain button on
// the page itself. With a navigation controller this does nothing.
- (void)SaoqiangWCAssetsInstallFallbackBackIfNeeded {
    if (self.navigationController) {
        self.SaoqiangWCAssetsFallbackBack.hidden = YES;
        return;
    }
    if (self.SaoqiangWCAssetsFallbackBack) {
        self.SaoqiangWCAssetsFallbackBack.hidden = NO;
        [self.view bringSubviewToFront:self.SaoqiangWCAssetsFallbackBack];
        return;
    }
    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    [back setTitle:@"‹" forState:UIControlStateNormal];
    [back setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    back.titleLabel.font = SaoqiangWCAssetsFont(30, UIFontWeightLight);
    back.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.92];
    back.layer.cornerRadius = 18;
    back.translatesAutoresizingMaskIntoConstraints = NO;
    [back addTarget:self action:@selector(SaoqiangWCAssetsNavBackTapped) forControlEvents:UIControlEventTouchUpInside];
    SaoqiangWCAssetsMarkOwnView(back);
    [self.view addSubview:back];
    [NSLayoutConstraint activateConstraints:@[
        [back.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:8],
        [back.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:6],
        [back.widthAnchor constraintEqualToConstant:36],
        [back.heightAnchor constraintEqualToConstant:36]
    ]];
    self.SaoqiangWCAssetsFallbackBack = back;
}
// 0.11.40: in card mode the header strip is the resize handle. Not everyone
// will try dragging it, so the same two states get a chevron in the bar.
- (void)SaoqiangWCAssetsInstallSheetToggleIfNeeded {
    SaoqiangWCAssetsSheetHost *host = self.SaoqiangWCAssetsSheet;
    if (!host) return;
    BOOL expanded = [host SaoqiangWCAssetsExpanded];
    UIBarButtonItem *toggle = [[UIBarButtonItem alloc]
        initWithImage:SaoqiangWCAssetsSymbol(expanded ? @"chevron.down" : @"chevron.up")
                style:UIBarButtonItemStylePlain target:self action:@selector(SaoqiangWCAssetsSheetToggleTapped)];
    toggle.tintColor = UIColor.labelColor;
    toggle.accessibilityLabel = expanded ? @"收起到半屏" : @"放大";
    self.navigationItem.rightBarButtonItem = toggle;
}
- (void)SaoqiangWCAssetsSheetToggleTapped {
    SaoqiangWCAssetsSheetHost *host = self.SaoqiangWCAssetsSheet;
    if (!host) return;
    [host SaoqiangWCAssetsSetExpanded:![host SaoqiangWCAssetsExpanded] animated:YES];
    [self SaoqiangWCAssetsInstallSheetToggleIfNeeded];
}
// Take over the nav controller's interactive pop so a right swipe on a
// sub-page cannot jump straight back to the WCRefine hub. Sub-pages use our
// own left-edge recognizer to step back to home; the home page keeps the
// system pop (and swipe-to-dismiss) for returning to the hub.
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    UINavigationController *nav = self.navigationController;
    if (nav && gestureRecognizer == nav.interactivePopGestureRecognizer) {
        if (self.SaoqiangWCAssetsPage != 0) return NO;
        return nav.viewControllers.count > 1;
    }
    if (gestureRecognizer == self.SaoqiangWCAssetsEdgePan) {
        return self.SaoqiangWCAssetsPage != 0;
    }
    return YES;
}
- (void)SaoqiangWCAssetsEdgeBack:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded && self.SaoqiangWCAssetsPage != 0) {
        [self SaoqiangWCAssetsShowPage:0];
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"小扒手";
    // Keep the system chevron look but take over its action for sub-pages.
    self.navigationItem.hidesBackButton = YES;
    UIBarButtonItem *navBack = [[UIBarButtonItem alloc] initWithTitle:@"‹"
        style:UIBarButtonItemStylePlain target:self action:@selector(SaoqiangWCAssetsNavBackTapped)];
    navBack.tintColor = UIColor.labelColor;
    [navBack setTitleTextAttributes:@{NSFontAttributeName:SaoqiangWCAssetsFont(26, UIFontWeightLight)} forState:UIControlStateNormal];
    self.navigationItem.leftBarButtonItem = navBack;
    // Swipe-from-left walks the same hierarchy as the chevron: sub-pages go
    // back to the home page, only the home page pops to the plugin hub.
    UIScreenEdgePanGestureRecognizer *edgePan = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(SaoqiangWCAssetsEdgeBack:)];
    edgePan.edges = UIRectEdgeLeft;
    edgePan.delegate = self;
    [self.view addGestureRecognizer:edgePan];
    self.SaoqiangWCAssetsEdgePan = edgePan;
    // Home shows its own logo + brand label instead of a duplicate nav title.
    self.navigationItem.title = @"";
    self.view.backgroundColor = SaoqiangWCAssetsCanvas();
    SaoqiangWCAssetsMarkOwnView(self.view);
    self.SaoqiangWCAssetsSelected = [NSMutableDictionary new];
    self.SaoqiangWCAssetsRows = @[];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    // One controller, three pages. Only container visibility changes on
    // navigation, so the capture/export code below keeps working untouched.
    UIView *home = [UIView new];
    UIView *iconPage = [UIView new];
    UIView *themePage = [UIView new];
    self.SaoqiangWCAssetsHomeView = home;
    self.SaoqiangWCAssetsIconPage = iconPage;
    self.SaoqiangWCAssetsThemePage = themePage;
    iconPage.hidden = YES;
    themePage.hidden = YES;
    // All three pages share one host container so the top/bottom padding is a
    // single pair of constants (see -viewDidLayoutSubviews).
    UIView *pagesHost = [UIView new];
    pagesHost.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:pagesHost];
    self.SaoqiangWCAssetsPagesHost = pagesHost;
    // 0.11.42: stop deriving the gap from safe-area numbers. Inside the card the
    // navigation controller is a child of a plain container, and on some iOS
    // versions its safe-area inset arrives as 0 — or as a stray status-bar value,
    // or only after the bar has already been laid out. The page container then
    // started *under* the bar and the 20pt page title was cut in half.
    // The required constraint added in -viewDidLayoutSubviews ties the container
    // to the bar view itself, so the real gap is solved by Auto Layout no matter
    // how the bar is hosted or when it is created. The equality below is only a
    // low-priority preference that keeps the position deterministic.
    self.SaoqiangWCAssetsPagesTop = [pagesHost.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:6];
    self.SaoqiangWCAssetsPagesTop.priority = UILayoutPriorityDefaultLow;
    self.SaoqiangWCAssetsPagesBottom = [pagesHost.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:0];
    [NSLayoutConstraint activateConstraints:@[
        self.SaoqiangWCAssetsPagesTop, self.SaoqiangWCAssetsPagesBottom,
        [pagesHost.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.topAnchor constant:6],
        [pagesHost.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [pagesHost.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    for (UIView *page in @[home, iconPage, themePage]) {
        page.translatesAutoresizingMaskIntoConstraints = NO;
        [pagesHost addSubview:page];
        [NSLayoutConstraint activateConstraints:@[
            [page.leadingAnchor constraintEqualToAnchor:pagesHost.leadingAnchor],
            [page.trailingAnchor constraintEqualToAnchor:pagesHost.trailingAnchor],
            [page.topAnchor constraintEqualToAnchor:pagesHost.topAnchor],
            [page.bottomAnchor constraintEqualToAnchor:pagesHost.bottomAnchor]
        ]];
    }

    // ===== Home: logo + brand title, then compact card =====
    UIImageView *logoView = [[UIImageView alloc] initWithImage:[SaoqiangWCAssetsLogoImage() imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    logoView.translatesAutoresizingMaskIntoConstraints = NO;
    logoView.contentMode = UIViewContentModeScaleAspectFit;
    logoView.tintColor = UIColor.labelColor;
    SaoqiangWCAssetsMarkOwnView(logoView);
    [home addSubview:logoView];

    UILabel *brandTitle = SaoqiangWCAssetsLabel(21, UIFontWeightBold);
    brandTitle.text = @"小扒手";
    brandTitle.textAlignment = NSTextAlignmentCenter;
    brandTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [home addSubview:brandTitle];

    UILabel *versionLabel = SaoqiangWCAssetsLabel(13, UIFontWeightRegular);
    versionLabel.text = [@"Version: " stringByAppendingString:SAOQIANG_WCASSETS_VERSION];
    versionLabel.textColor = UIColor.secondaryLabelColor;
    versionLabel.textAlignment = NSTextAlignmentCenter;
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [home addSubview:versionLabel];

    UIView *card = [UIView new];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    card.layer.cornerRadius = 16;
    [home addSubview:card];

    UILabel *enableTitle = SaoqiangWCAssetsLabel(17, UIFontWeightSemibold);
    enableTitle.text = @"启用插件";
    enableTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:enableTitle];

    SaoqiangWCAssetsToggle *masterSwitch = [SaoqiangWCAssetsToggle new];
    masterSwitch.on = SaoqiangWCAssetsMasterEnabled();
    SaoqiangWCAssetsMarkOwnView(masterSwitch);
    [masterSwitch addTarget:self action:@selector(SaoqiangWCAssetsMasterChanged:) forControlEvents:UIControlEventValueChanged];
    masterSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.SaoqiangWCAssetsMasterSwitch = masterSwitch;
    [card addSubview:masterSwitch];

    UIButton *iconEntry = [self SaoqiangWCAssetsEntryButton:@"抓取图标" action:@selector(SaoqiangWCAssetsIconEntryTapped)];
    UIButton *themeEntry = [self SaoqiangWCAssetsEntryButton:@"抓取主题" action:@selector(SaoqiangWCAssetsThemeEntryTapped)];
    self.SaoqiangWCAssetsIconEntry = iconEntry;
    self.SaoqiangWCAssetsThemeEntry = themeEntry;
    [card addSubview:iconEntry];
    [card addSubview:themeEntry];

    [NSLayoutConstraint activateConstraints:@[
        [logoView.topAnchor constraintEqualToAnchor:home.topAnchor constant:20],
        [logoView.centerXAnchor constraintEqualToAnchor:home.centerXAnchor],
        [logoView.widthAnchor constraintEqualToConstant:54],
        [logoView.heightAnchor constraintEqualToConstant:54],
        [brandTitle.topAnchor constraintEqualToAnchor:logoView.bottomAnchor constant:6],
        [brandTitle.centerXAnchor constraintEqualToAnchor:home.centerXAnchor],
        [versionLabel.topAnchor constraintEqualToAnchor:brandTitle.bottomAnchor constant:2],
        [versionLabel.centerXAnchor constraintEqualToAnchor:home.centerXAnchor],
        [card.topAnchor constraintEqualToAnchor:versionLabel.bottomAnchor constant:10],
        [card.leadingAnchor constraintEqualToAnchor:home.leadingAnchor constant:16],
        [card.trailingAnchor constraintEqualToAnchor:home.trailingAnchor constant:-16],
        [card.heightAnchor constraintEqualToConstant:160],
        [enableTitle.topAnchor constraintEqualToAnchor:card.topAnchor constant:18],
        [enableTitle.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [enableTitle.trailingAnchor constraintLessThanOrEqualToAnchor:masterSwitch.leadingAnchor constant:-8],
        [masterSwitch.centerYAnchor constraintEqualToAnchor:enableTitle.centerYAnchor],
        [masterSwitch.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [masterSwitch.widthAnchor constraintEqualToConstant:51],
        [masterSwitch.heightAnchor constraintEqualToConstant:31],
        [iconEntry.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [iconEntry.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [iconEntry.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-58],
        [themeEntry.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
        [themeEntry.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        [themeEntry.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-6]
    ]];

    // ===== Icon page: centered 抓取图标名称 title, four tabs, record list =====
    // Per request the old header row (返回 / 抓取图标 / 关闭) is gone entirely.
    // The main title now sits directly under the safe-area top edge.
    UILabel *iconTitle = SaoqiangWCAssetsLabel(20, UIFontWeightBold);
    iconTitle.text = @"抓取图标名称";
    iconTitle.textAlignment = NSTextAlignmentCenter;

    // Summary text is hidden per request; the object stays alive because the
    // diagnostics copy action still reads its text.
    self.SaoqiangWCAssetsSummary = SaoqiangWCAssetsLabel(10, UIFontWeightRegular);
    self.SaoqiangWCAssetsSummary.textColor = UIColor.secondaryLabelColor;
    self.SaoqiangWCAssetsSummary.adjustsFontSizeToFitWidth = YES;
    self.SaoqiangWCAssetsSummary.minimumScaleFactor = 0.8;
    self.SaoqiangWCAssetsSummary.hidden = YES;

    // Plain text toggle above the four tabs: black before capture starts,
    // green while it runs. Both actions share a centered row.
    UIView *actionRow = [UIView new];
    actionRow.translatesAutoresizingMaskIntoConstraints = NO;
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.translatesAutoresizingMaskIntoConstraints = NO;
    [startButton setTitle:@"开始抓取" forState:UIControlStateNormal];
    [startButton setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    startButton.titleLabel.font = SaoqiangWCAssetsFont(18, UIFontWeightSemibold);
    [startButton addTarget:self action:@selector(SaoqiangWCAssetsStartTapped) forControlEvents:UIControlEventTouchUpInside];
    SaoqiangWCAssetsMarkOwnView(startButton);
    self.SaoqiangWCAssetsStartButton = startButton;
    [actionRow addSubview:startButton];

    // Same row: jump straight back to the WeChat home tab without walking
    // through every page.
    UIButton *homeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    homeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [homeButton setTitle:@"返回微信首页" forState:UIControlStateNormal];
    [homeButton setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    homeButton.titleLabel.font = SaoqiangWCAssetsFont(18, UIFontWeightSemibold);
    [homeButton addTarget:self action:@selector(SaoqiangWCAssetsBackToWeChatHome) forControlEvents:UIControlEventTouchUpInside];
    SaoqiangWCAssetsMarkOwnView(homeButton);
    self.SaoqiangWCAssetsHomeButton = homeButton;
    [actionRow addSubview:homeButton];

    // Helper line mirrors the summary under 抓取图标名称 (size 10, secondary).
    UILabel *startHint = SaoqiangWCAssetsLabel(10, UIFontWeightRegular);
    startHint.text = @"点击开始抓取后开始抓取图标";
    startHint.textColor = UIColor.secondaryLabelColor;
    startHint.numberOfLines = 0;
    startHint.textAlignment = NSTextAlignmentCenter;
    self.SaoqiangWCAssetsStartHint = startHint;

    self.SaoqiangWCAssetsFilter = [[UISegmentedControl alloc] initWithItems:@[@"当前", @"SVG", @"PNG", @"原生"]];
    UISegmentedControl *filter = self.SaoqiangWCAssetsFilter;
    filter.selectedSegmentIndex = 0;
    filter.selectedSegmentTintColor = UIColor.blackColor;
    [filter setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.labelColor, NSFontAttributeName:SaoqiangWCAssetsFont(13, UIFontWeightRegular)} forState:UIControlStateNormal];
    [filter setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.whiteColor} forState:UIControlStateSelected];
    [filter addTarget:self action:@selector(SaoqiangWCAssetsFilterChanged) forControlEvents:UIControlEventValueChanged];

    // 0.11.40: capture summary strip, sat above the 清空 row. Shows how many
    // icons were grabbed and how they break down by format. Type sizes stay
    // small on purpose: in a 3/5-height panel this row must not take space the
    // list needs.
    UIView *stats = [UIView new];
    stats.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    stats.layer.cornerRadius = 12;
    stats.translatesAutoresizingMaskIntoConstraints = NO;
    SaoqiangWCAssetsMarkOwnView(stats);

    UIStackView *statRow = [UIStackView new];
    statRow.axis = UILayoutConstraintAxisHorizontal;
    statRow.distribution = UIStackViewDistributionFillEqually;
    statRow.spacing = 2;
    statRow.translatesAutoresizingMaskIntoConstraints = NO;
    [stats addSubview:statRow];

    NSArray *statTitles = @[@"总数", @"PNG", @"SVG", @"原生"];
    NSArray *statColors = @[UIColor.labelColor, UIColor.systemBlueColor, UIColor.systemPurpleColor, UIColor.systemGreenColor];
    NSMutableArray *statValues = [NSMutableArray new];
    for (NSUInteger index = 0; index < statTitles.count; index++) {
        UILabel *value = SaoqiangWCAssetsLabel(17, UIFontWeightSemibold);
        value.text = @"0";
        value.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightSemibold];
        value.textColor = statColors[index];
        value.textAlignment = NSTextAlignmentCenter;
        value.adjustsFontSizeToFitWidth = YES;
        value.minimumScaleFactor = 0.7;
        UILabel *caption = SaoqiangWCAssetsLabel(10, UIFontWeightRegular);
        caption.text = statTitles[index];
        caption.textColor = UIColor.secondaryLabelColor;
        caption.textAlignment = NSTextAlignmentCenter;
        UIStackView *column = [[UIStackView alloc] initWithArrangedSubviews:@[value, caption]];
        column.axis = UILayoutConstraintAxisVertical;
        column.alignment = UIStackViewAlignmentFill;
        column.spacing = 0;
        [statRow addArrangedSubview:column];
        [statValues addObject:value];
    }
    self.SaoqiangWCAssetsTotalValue = statValues[0];
    self.SaoqiangWCAssetsPNGValue = statValues[1];
    self.SaoqiangWCAssetsSVGValue = statValues[2];
    self.SaoqiangWCAssetsNativeValue = statValues[3];
    stats.accessibilityLabel = @"抓取统计：总数、PNG、SVG、原生";

    self.SaoqiangWCAssetsClearButton = SaoqiangWCAssetsButton(@"清空", self, @selector(SaoqiangWCAssetsConfirmClear));

    for (UIView *view in @[iconTitle, actionRow, startHint, filter, stats, self.SaoqiangWCAssetsClearButton]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [iconPage addSubview:view];
    }

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.SaoqiangWCAssetsTable = table;
    table.translatesAutoresizingMaskIntoConstraints = NO;
    table.backgroundColor = UIColor.clearColor;
    table.dataSource = self;
    table.delegate = self;
    table.separatorStyle = UITableViewCellSeparatorStyleNone;
    table.rowHeight = 80;
    table.estimatedRowHeight = 80;
    table.allowsMultipleSelection = YES;
    table.contentInset = UIEdgeInsetsMake(6, 0, 12, 0);
    table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [table registerClass:SaoqiangWCAssetsCell.class forCellReuseIdentifier:@"SaoqiangWCAssetsCell"];
    [iconPage addSubview:table];
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(SaoqiangWCAssetsLongPressRow:)];
    press.delegate = self;
    [table addGestureRecognizer:press];
    self.SaoqiangWCAssetsEmpty = SaoqiangWCAssetsLabel(13, UIFontWeightRegular);
    self.SaoqiangWCAssetsEmpty.numberOfLines = 0;
    self.SaoqiangWCAssetsEmpty.textAlignment = NSTextAlignmentCenter;
    self.SaoqiangWCAssetsEmpty.textColor = UIColor.secondaryLabelColor;
    self.SaoqiangWCAssetsEmpty.userInteractionEnabled = NO;
    table.backgroundView = self.SaoqiangWCAssetsEmpty;

    UIButton *clear = self.SaoqiangWCAssetsClearButton;
    [NSLayoutConstraint activateConstraints:@[
        [iconTitle.topAnchor constraintEqualToAnchor:iconPage.topAnchor constant:12],
        [iconTitle.centerXAnchor constraintEqualToAnchor:iconPage.centerXAnchor],
        [actionRow.topAnchor constraintEqualToAnchor:iconTitle.bottomAnchor constant:14],
        [actionRow.centerXAnchor constraintEqualToAnchor:iconPage.centerXAnchor],
        [actionRow.heightAnchor constraintEqualToConstant:36],
        [startButton.leadingAnchor constraintEqualToAnchor:actionRow.leadingAnchor],
        [startButton.topAnchor constraintEqualToAnchor:actionRow.topAnchor],
        [startButton.bottomAnchor constraintEqualToAnchor:actionRow.bottomAnchor],
        [homeButton.leadingAnchor constraintEqualToAnchor:startButton.trailingAnchor constant:28],
        [homeButton.topAnchor constraintEqualToAnchor:actionRow.topAnchor],
        [homeButton.bottomAnchor constraintEqualToAnchor:actionRow.bottomAnchor],
        [homeButton.trailingAnchor constraintEqualToAnchor:actionRow.trailingAnchor],
        [startHint.topAnchor constraintEqualToAnchor:actionRow.bottomAnchor constant:6],
        [startHint.leadingAnchor constraintEqualToAnchor:iconPage.leadingAnchor constant:20],
        [startHint.trailingAnchor constraintEqualToAnchor:iconPage.trailingAnchor constant:-20],
        [filter.topAnchor constraintEqualToAnchor:startHint.bottomAnchor constant:8],
        [filter.heightAnchor constraintEqualToConstant:34],
        [filter.leadingAnchor constraintEqualToAnchor:iconPage.leadingAnchor constant:20],
        [filter.trailingAnchor constraintEqualToAnchor:iconPage.trailingAnchor constant:-20],
        [statRow.topAnchor constraintEqualToAnchor:stats.topAnchor constant:6],
        [statRow.bottomAnchor constraintEqualToAnchor:stats.bottomAnchor constant:-6],
        [statRow.leadingAnchor constraintEqualToAnchor:stats.leadingAnchor constant:6],
        [statRow.trailingAnchor constraintEqualToAnchor:stats.trailingAnchor constant:-6],
        [stats.topAnchor constraintEqualToAnchor:filter.bottomAnchor constant:8],
        [stats.leadingAnchor constraintEqualToAnchor:iconPage.leadingAnchor constant:20],
        [stats.trailingAnchor constraintEqualToAnchor:iconPage.trailingAnchor constant:-20],
        [stats.heightAnchor constraintEqualToConstant:46],
        [clear.topAnchor constraintEqualToAnchor:stats.bottomAnchor constant:6],
        [clear.trailingAnchor constraintEqualToAnchor:iconPage.trailingAnchor constant:-20],
        [clear.widthAnchor constraintEqualToConstant:56],
        [clear.heightAnchor constraintEqualToConstant:32],
        [table.topAnchor constraintEqualToAnchor:clear.bottomAnchor constant:6],
        [table.leadingAnchor constraintEqualToAnchor:iconPage.leadingAnchor],
        [table.trailingAnchor constraintEqualToAnchor:iconPage.trailingAnchor],
        [table.bottomAnchor constraintEqualToAnchor:iconPage.bottomAnchor]
    ]];

    // ===== Theme page: theme tools (抓取当前主题 switch removed per request) =====
    // Per request the 返回 / 关闭 header buttons are removed; only the page
    // title stays, pinned to the top of the safe area.
    UILabel *themePageTitle = SaoqiangWCAssetsLabel(17, UIFontWeightSemibold);
    themePageTitle.text = @"抓取主题";
    themePageTitle.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *themeTitle = SaoqiangWCAssetsLabel(16, UIFontWeightSemibold);
    themeTitle.text = @"抓取当前主题";

    // Hidden target kept for the UI harness; the theme page shows the tools
    // directly instead of switching through a tab button.
    UIButton *themeTab = SaoqiangWCAssetsButton(@"抓取主题", self, @selector(SaoqiangWCAssetsThemeTabTapped));
    themeTab.hidden = YES;
    self.SaoqiangWCAssetsThemeTabButton = themeTab;

    for (UIView *view in @[themePageTitle, themeTitle, themeTab]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [themePage addSubview:view];
    }
    [self SaoqiangWCAssetsBuildTools];

    [NSLayoutConstraint activateConstraints:@[
        [themePageTitle.topAnchor constraintEqualToAnchor:themePage.topAnchor constant:10],
        [themePageTitle.centerXAnchor constraintEqualToAnchor:themePage.centerXAnchor],
        [themeTitle.topAnchor constraintEqualToAnchor:themePageTitle.bottomAnchor constant:20],
        [themeTitle.leadingAnchor constraintEqualToAnchor:themePage.leadingAnchor constant:20],
        [themeTitle.trailingAnchor constraintLessThanOrEqualToAnchor:themePage.trailingAnchor constant:-20],
        [self.SaoqiangWCAssetsToolsScroll.topAnchor constraintEqualToAnchor:themeTitle.bottomAnchor constant:16],
        [self.SaoqiangWCAssetsToolsScroll.leadingAnchor constraintEqualToAnchor:themePage.leadingAnchor],
        [self.SaoqiangWCAssetsToolsScroll.trailingAnchor constraintEqualToAnchor:themePage.trailingAnchor],
        [self.SaoqiangWCAssetsToolsScroll.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor]
    ]];

    // Toast stays above all three pages.
    UILabel *feedback = SaoqiangWCAssetsLabel(12, UIFontWeightMedium);
    self.SaoqiangWCAssetsFeedback = feedback;
    feedback.backgroundColor = UIColor.labelColor;
    feedback.textColor = UIColor.systemBackgroundColor;
    feedback.textAlignment = NSTextAlignmentCenter;
    feedback.numberOfLines = 0;
    feedback.layer.cornerRadius = 12;
    feedback.clipsToBounds = YES;
    feedback.hidden = YES;
    feedback.userInteractionEnabled = NO;
    feedback.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:feedback];
    [NSLayoutConstraint activateConstraints:@[
        [feedback.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [feedback.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [feedback.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor constant:-12],
        [feedback.heightAnchor constraintGreaterThanOrEqualToConstant:40]
    ]];

    [self SaoqiangWCAssetsRefresh:YES];
}
// The page titles must clear the navigation bar. Inside the draggable card the
// nav controller is hosted in a child container, and its safe-area insets were
// arriving as zero there, so pinning to safeAreaLayoutGuide.left the titles
// half-hidden behind the bar. Resolve the real bar bottom + real bottom inset
// from the window on every layout pass instead.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // 0.11.42: pin the page container to the bar's own bottom edge instead of
    // trusting safe-area numbers. hosting the navigation controller in a child
    // container makes those insets unreliable (zero, or a status-bar value), and
    // recomputing them by hand left the title half-covered on device.
    // pagesHost (inside self.view) and the bar (inside the navigation
    // controller's view) share the navigation view as an ancestor, so Auto
    // Layout can resolve this across the hierarchy and keep it correct even when
    // the bar is created after the first layout pass.
    UINavigationBar *bar = self.navigationController.navigationBar;
    if (bar && !self.SaoqiangWCAssetsPagesBarGap && self.SaoqiangWCAssetsPagesHost) {
        // 0.11.43: the 10pt gap only just cleared the bar, so every page title
        // still looked jammed against it (「名称不挡住了，但还是太上了」).
        // 26pt below the bar's own bottom edge reads as a real header inset.
        NSLayoutConstraint *gap = [NSLayoutConstraint constraintWithItem:self.SaoqiangWCAssetsPagesHost
            attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationGreaterThanOrEqual
            toItem:bar attribute:NSLayoutAttributeBottom multiplier:1 constant:26];
        gap.active = YES;
        self.SaoqiangWCAssetsPagesBarGap = gap;
    }
    CGFloat bottom = self.view.safeAreaInsets.bottom;
    UIWindow *window = self.view.window;
    if (window) {
        CGRect here = [self.view convertRect:self.view.bounds toView:window];
        CGFloat clipped = MAX(0, CGRectGetMaxY(here) - CGRectGetMaxY(window.bounds));
        bottom = MAX(bottom, window.safeAreaInsets.bottom - clipped);
    }
    if (!isfinite(bottom) || bottom < 0) bottom = 0;
    if (fabs(self.SaoqiangWCAssetsPagesBottom.constant + bottom) > 0.5) self.SaoqiangWCAssetsPagesBottom.constant = -bottom;
}
- (void)SaoqiangWCAssetsBuildTools {
    UIScrollView *scroll = [UIScrollView new]; self.SaoqiangWCAssetsToolsScroll = scroll; scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag; scroll.hidden = YES; [self.SaoqiangWCAssetsThemePage addSubview:scroll];
    UIStackView *stack = [UIStackView new]; stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 6; stack.translatesAutoresizingMaskIntoConstraints = NO; [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20], [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:10], [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-20],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40]
    ]];
    self.SaoqiangWCAssetsThemeButton = SaoqiangWCAssetsButton(@"当前主题素材一键导出", self, @selector(SaoqiangWCAssetsExportTheme));
    [self.SaoqiangWCAssetsThemeButton.heightAnchor constraintEqualToConstant:44].active = YES;
    [stack addArrangedSubview:self.SaoqiangWCAssetsThemeButton];
    UIButton *referenceButton=SaoqiangWCAssetsButton(@"导入 / 移除当前主题对照清单",self,@selector(SaoqiangWCAssetsReferenceMenu));
    [referenceButton.heightAnchor constraintEqualToConstant:40].active=YES;[stack addArrangedSubview:referenceButton];
    self.SaoqiangWCAssetsThemeProgress = SaoqiangWCAssetsLabel(11, UIFontWeightRegular);
    self.SaoqiangWCAssetsThemeProgress.numberOfLines = 0; self.SaoqiangWCAssetsThemeProgress.textColor = UIColor.secondaryLabelColor;
    [stack addArrangedSubview:self.SaoqiangWCAssetsThemeProgress]; [stack setCustomSpacing:16 afterView:self.SaoqiangWCAssetsThemeProgress];
    UISearchBar *search = [UISearchBar new]; self.SaoqiangWCAssetsSearch = search;
    search.searchBarStyle = UISearchBarStyleMinimal; search.placeholder = @"搜索资源名称"; search.delegate = self; search.returnKeyType = UIReturnKeySearch;
    search.searchTextField.font = SaoqiangWCAssetsFont(13, UIFontWeightRegular); search.searchTextField.backgroundColor = UIColor.clearColor;
    [stack addArrangedSubview:search]; [stack setCustomSpacing:16 afterView:search];
    self.SaoqiangWCAssetsScopeLabel = SaoqiangWCAssetsLabel(11, UIFontWeightRegular); self.SaoqiangWCAssetsScopeLabel.numberOfLines = 2;
    self.SaoqiangWCAssetsScopeLabel.textColor = UIColor.secondaryLabelColor; [stack addArrangedSubview:self.SaoqiangWCAssetsScopeLabel];
    // 全选 / 导出所选 / 导出目录 / 复制识别诊断 / 关闭 五个按钮已按需求移除。
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated]; SaoqiangWCAssetsPresentedController = self;
    // In the 0.11.40 card host the presentation controller belongs to the host,
    // so its delegate stays untouched and dismissal callbacks keep one owner.
    if (!self.SaoqiangWCAssetsSheet) self.presentationController.delegate = self;
    // The ‹ chevron lives in navigationItem, so it only exists on screen while
    // a navigation bar is visible. The panel is pushed by WCRefine's plugin hub
    // or presented by the global gesture inside our own UINavigationController;
    // both must keep the bar on, otherwise the panel loses its only way out.
    self.navigationController.navigationBarHidden = NO;
    // The bar may only come into existence here (older iOS creates it lazily),
    // so ask for a layout pass: the bar-gap constraint is installed from
    // -viewDidLayoutSubviews and must be resolved before the first frame.
    [self.view setNeedsLayout];
    [self SaoqiangWCAssetsInstallFallbackBackIfNeeded];
    [self SaoqiangWCAssetsInstallSheetToggleIfNeeded];
    // Take over interactive pop while this panel is visible so sub-page swipes
    // step back to home instead of popping straight to the plugin hub.
    UINavigationController *nav = self.navigationController;
    if (nav && nav.interactivePopGestureRecognizer && !self.SaoqiangWCAssetsPopDelegateInstalled) {
        self.SaoqiangWCAssetsSavedPopDelegate = nav.interactivePopGestureRecognizer.delegate;
        nav.interactivePopGestureRecognizer.delegate = (id<UIGestureRecognizerDelegate>)self;
        self.SaoqiangWCAssetsPopDelegateInstalled = YES;
    }
    if (!self.SaoqiangWCAssetsOwnUICounted) { self.SaoqiangWCAssetsOwnUICounted = YES; SaoqiangWCAssetsNoteOwnUI(YES); }
    [self.SaoqiangWCAssetsTimer invalidate]; __weak typeof(self) weakSelf = self;
    self.SaoqiangWCAssetsTimer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        typeof(self) owner = weakSelf;
        if (!owner) { [timer invalidate]; return; }
        // 0.11.44: this timer runs in common modes, so it ticked *through* every
        // scroll. Doing the work then forced a rebuild under the moving finger —
        // the dropped frames. Defer to the scroll-ended callbacks instead.
        UITableView *table = owner.SaoqiangWCAssetsTable;
        if (!owner.SaoqiangWCAssetsThemeTab && (table.tracking || table.dragging ||
            table.decelerating || owner.SaoqiangWCAssetsContextOpen)) {
            owner.SaoqiangWCAssetsPendingRefresh = YES; return;
        }
        [owner SaoqiangWCAssetsRefreshTheme];
        if (!owner.presentedViewController && !owner.SaoqiangWCAssetsBusy) [owner SaoqiangWCAssetsRefresh:NO];
    }];
    self.SaoqiangWCAssetsTimer.tolerance = 0.3;
    [[NSRunLoop mainRunLoop] addTimer:self.SaoqiangWCAssetsTimer forMode:NSRunLoopCommonModes]; [self SaoqiangWCAssetsRefresh:NO];
}
- (void)viewDidAppear:(BOOL)animated {
    // 0.11.39: the「轻点卡片多选；长按卡片可单项保存」hint toast is gone. It was
    // fired from here, so it also reappeared whenever the panel came back from
    // a presented picker/alert, over the bottom of the page.
    [super viewDidAppear:animated];
}
- (void)SaoqiangWCAssetsRestorePopDelegate {
    if (!self.SaoqiangWCAssetsPopDelegateInstalled) return;
    UINavigationController *nav = self.navigationController;
    if (nav && nav.interactivePopGestureRecognizer.delegate == (id<UIGestureRecognizerDelegate>)self) {
        nav.interactivePopGestureRecognizer.delegate = self.SaoqiangWCAssetsSavedPopDelegate;
    }
    self.SaoqiangWCAssetsSavedPopDelegate = nil;
    self.SaoqiangWCAssetsPopDelegateInstalled = NO;
}
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated]; [self.SaoqiangWCAssetsTimer invalidate];
    [self SaoqiangWCAssetsRestorePopDelegate];
    if (self.SaoqiangWCAssetsOwnUICounted) { self.SaoqiangWCAssetsOwnUICounted = NO; SaoqiangWCAssetsNoteOwnUI(NO); }
    // 0.11.41: a capture pass is refused while our own UI is on screen, so the
    //「开始抓取」tap inside the panel never samples anything. Sample once as soon
    // as the panel is gone, instead of waiting for the next timer tick.
    dispatch_async(dispatch_get_main_queue(), ^{ SaoqiangWCAssetsCaptureVisiblePage(); });
}
- (void)dealloc {
    [_SaoqiangWCAssetsTimer invalidate];
    UINavigationController *nav = _SaoqiangWCAssetsPopDelegateInstalled ? self.navigationController : nil;
    if (nav && nav.interactivePopGestureRecognizer.delegate == (id<UIGestureRecognizerDelegate>)self) {
        nav.interactivePopGestureRecognizer.delegate = _SaoqiangWCAssetsSavedPopDelegate;
    }
    if (_SaoqiangWCAssetsOwnUICounted) { _SaoqiangWCAssetsOwnUICounted = NO; SaoqiangWCAssetsNoteOwnUI(NO); }
}
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    if (presentationController.presentedViewController == self) {
        [self.SaoqiangWCAssetsTimer invalidate]; if (SaoqiangWCAssetsPresentedController == self) SaoqiangWCAssetsPresentedController = nil;
    }
}
// The gesture shortcut wraps the panel in a card host (0.11.40); dismissing the
// host is what actually takes the panel off screen. The plugin-hub entry
// presents the navigation controller itself, so both cases resolve to one
// target and every close path below stays single-source.
- (UIViewController *)SaoqiangWCAssetsDismissTarget {
    return (UIViewController *)self.SaoqiangWCAssetsSheet ?: self;
}
- (void)SaoqiangWCAssetsClose {
    if (self.SaoqiangWCAssetsBusy || self.presentedViewController) return;
    [self.view endEditing:YES]; [[self SaoqiangWCAssetsDismissTarget] dismissViewControllerAnimated:YES completion:^{
        if (SaoqiangWCAssetsPresentedController == self) SaoqiangWCAssetsPresentedController = nil;
    }];
}
- (void)SaoqiangWCAssetsMasterChanged:(SaoqiangWCAssetsToggle *)sender {
    SaoqiangWCAssetsSetMasterEnabled(sender.on);
    [self SaoqiangWCAssetsUpdateSelection];
    [self SaoqiangWCAssetsToast:sender.on ? @"总开关已开启 · 点开始抓取即可抓取图标" : @"总开关已关闭 · 插件保持注入但不抓取"];
}
- (void)SaoqiangWCAssetsStartTapped {
    if (!SaoqiangWCAssetsMasterEnabled()) {
        [self SaoqiangWCAssetsToast:@"请先打开启用插件总开关"]; return;
    }
    // 图标功能开关已取消，开始抓取是唯一入口，无需再检查图标开关。
    BOOL capturing = !SaoqiangWCAssetsIconCapturing();
    SaoqiangWCAssetsSetIconCapturing(capturing);
    [self SaoqiangWCAssetsUpdateSelection];
    [self SaoqiangWCAssetsToast:capturing ? @"已开始抓取图标" : @"已停止抓取图标"];
}
- (void)SaoqiangWCAssetsBackToWeChatHome {
    // Our panel is presented full-screen on top of WeChat. Dismiss it first,
    // then unwind whatever page is underneath back to the main tab, so the
    // user does not have to tap back through every screen.
    UIViewController *presenter = [self SaoqiangWCAssetsDismissTarget].presentingViewController;
    [self.view endEditing:YES];
    [[self SaoqiangWCAssetsDismissTarget] dismissViewControllerAnimated:YES completion:^{
        if (SaoqiangWCAssetsPresentedController == self) SaoqiangWCAssetsPresentedController = nil;
        dispatch_async(dispatch_get_main_queue(), ^{ SaoqiangWCAssetsUnwindWeChatHome(presenter); });
    }];
}
- (void)SaoqiangWCAssetsThemeTabTapped {
    [self SaoqiangWCAssetsShowPage:2];
}
- (void)SaoqiangWCAssetsFilterChanged {
    self.SaoqiangWCAssetsThemeTab = NO;
    self.SaoqiangWCAssetsLastListFilter = self.SaoqiangWCAssetsFilter.selectedSegmentIndex;
    [self.view endEditing:YES]; [self SaoqiangWCAssetsRefresh:YES];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText { [self SaoqiangWCAssetsRefresh:YES]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [self.sheetPresentationController animateChanges:^{
        if (@available(iOS 16.0,*)) self.sheetPresentationController.selectedDetentIdentifier = self.sheetPresentationController.detents.lastObject.identifier;
        else self.sheetPresentationController.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
    }];
}
- (void)SaoqiangWCAssetsRefresh:(BOOL)reset {
    if (!self.isViewLoaded) return;
    SaoqiangWCAssetsPushSuppression();
    @try {
        SaoqiangWCAssetsStore *store = [SaoqiangWCAssetsStore SaoqiangWCAssetsShared];
        NSString *query = [self.SaoqiangWCAssetsSearch.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
        SaoqiangWCAssetsFilterKind filter = self.SaoqiangWCAssetsLastListFilter; BOOL tools = self.SaoqiangWCAssetsThemeTab;
        NSUInteger revision = [store SaoqiangWCAssetsRevision];
        // 0.11.44: nothing new captured and nothing the user changed, so the rows
        // already on screen are still correct. This is what makes an idle panel
        // cost nothing per tick instead of a full rebuild.
        if (!reset && self.SaoqiangWCAssetsBuiltValid && revision == self.SaoqiangWCAssetsBuiltRevision &&
            filter == self.SaoqiangWCAssetsBuiltFilter && tools == self.SaoqiangWCAssetsBuiltTools &&
            [query isEqualToString:self.SaoqiangWCAssetsBuiltQuery ?: @""]) return;
        NSString *runtimeID = [store SaoqiangWCAssetsCollectionState][@"runtimeID"];
        NSMutableArray *rows = [NSMutableArray new], *identities = [NSMutableArray new]; NSMutableDictionary *current = [NSMutableDictionary new];
        self.SaoqiangWCAssetsCurrentCount = self.SaoqiangWCAssetsSVGCount = self.SaoqiangWCAssetsPNGCount = 0;
        self.SaoqiangWCAssetsNativeCount = 0;
        for (SaoqiangWCAssetsRecord *record in [store SaoqiangWCAssetsSnapshot].reverseObjectEnumerator) {
            if (!SaoqiangWCAssetsIsCurrent(record, runtimeID)) continue;
            BOOL svg = SaoqiangWCAssetsIsSVG(record), png = [record.kind.uppercaseString isEqualToString:@"PNG"];
            self.SaoqiangWCAssetsCurrentCount++; self.SaoqiangWCAssetsSVGCount += svg; self.SaoqiangWCAssetsPNGCount += png;
            self.SaoqiangWCAssetsNativeCount += SaoqiangWCAssetsIsNative(record);
            if (record.identity.length) current[record.identity] = record;
            BOOL matches = filter == SaoqiangWCAssetsFilterCurrent || (filter == SaoqiangWCAssetsFilterSVG && svg) ||
                (filter == SaoqiangWCAssetsFilterPNG && png) || (filter == SaoqiangWCAssetsFilterNative && SaoqiangWCAssetsIsNative(record));
            if (matches && (!query.length || [record.name localizedCaseInsensitiveContainsString:query])) { [rows addObject:record]; [identities addObject:record.identity ?: @""]; }
        }
        // Selection is rebound by identity and never outlives this runtime session.
        for (NSString *identity in self.SaoqiangWCAssetsSelected.allKeys) {
            if (current[identity]) self.SaoqiangWCAssetsSelected[identity] = current[identity]; else [self.SaoqiangWCAssetsSelected removeObjectForKey:identity];
        }
        self.SaoqiangWCAssetsTable.hidden = tools; self.SaoqiangWCAssetsToolsScroll.hidden = !tools;
        UIButton *themeTab = self.SaoqiangWCAssetsThemeTabButton;
        themeTab.backgroundColor = tools ? UIColor.labelColor : UIColor.secondarySystemGroupedBackgroundColor;
        [themeTab setTitleColor:tools ? UIColor.systemBackgroundColor : UIColor.labelColor forState:UIControlStateNormal];
        UITableView *table = self.SaoqiangWCAssetsTable;
        BOOL tracking = table.tracking || table.dragging || table.decelerating || self.SaoqiangWCAssetsContextOpen;
        if (tracking) { self.SaoqiangWCAssetsPendingRefresh = YES; self.SaoqiangWCAssetsPendingReset |= reset; }
        else {
            reset |= self.SaoqiangWCAssetsPendingReset; self.SaoqiangWCAssetsPendingRefresh = self.SaoqiangWCAssetsPendingReset = NO;
            BOOL changed = ![identities isEqualToArray:self.SaoqiangWCAssetsIdentities];
            NSIndexPath *first = table.indexPathsForVisibleRows.firstObject;
            NSString *anchor = !reset && first && (NSUInteger)first.row < self.SaoqiangWCAssetsRows.count ? self.SaoqiangWCAssetsRows[first.row].identity : nil;
            CGFloat offset = first ? table.contentOffset.y - [table rectForRowAtIndexPath:first].origin.y : 0;
            self.SaoqiangWCAssetsRows = rows; self.SaoqiangWCAssetsIdentities = identities;
            self.SaoqiangWCAssetsBuiltRevision = revision; self.SaoqiangWCAssetsBuiltQuery = [query copy];
            self.SaoqiangWCAssetsBuiltFilter = filter; self.SaoqiangWCAssetsBuiltTools = tools;
            self.SaoqiangWCAssetsBuiltValid = YES;
            [UIView performWithoutAnimation:^{
                if (changed) { [table reloadData]; [table layoutIfNeeded]; }
                else for (NSIndexPath *path in table.indexPathsForVisibleRows) if ((NSUInteger)path.row < rows.count) [self SaoqiangWCAssetsBindCell:(SaoqiangWCAssetsCell *)[table cellForRowAtIndexPath:path] record:rows[path.row]];
                if (reset) [table setContentOffset:CGPointMake(0, -table.adjustedContentInset.top) animated:NO];
                else if (changed && anchor.length) {
                    NSUInteger index = [identities indexOfObject:anchor];
                    if (index != NSNotFound) {
                        CGFloat y = [table rectForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]].origin.y + offset;
                        CGFloat maximum = MAX(-table.adjustedContentInset.top, table.contentSize.height - table.bounds.size.height + table.adjustedContentInset.bottom);
                        table.contentOffset = CGPointMake(0, MIN(maximum, MAX(-table.adjustedContentInset.top, y)));
                    }
                }
                [self SaoqiangWCAssetsSyncSelection];
            }];
        }
        self.SaoqiangWCAssetsEmpty.hidden = self.SaoqiangWCAssetsRows.count > 0;
        self.SaoqiangWCAssetsEmpty.text = query.length ? @"没有匹配的资源" : @"暂无已抓取素材\n开启后浏览页面，跨页累计保留";
        [self SaoqiangWCAssetsUpdateSelection];
    } @finally { SaoqiangWCAssetsPopSuppression(); }
}
- (void)SaoqiangWCAssetsSyncSelection {
    // 0.11.44: only the rows the table is actually showing. The old loop built an
    // index path and called select/deselect for every captured record, on every
    // tick — O(n) table traffic for a handful of visible cells. Rows that scroll
    // in are synced by -tableView:willDisplayCell: instead.
    UITableView *table = self.SaoqiangWCAssetsTable;
    NSSet *selectedPaths = [NSSet setWithArray:table.indexPathsForSelectedRows ?: @[]];
    for (NSIndexPath *path in table.indexPathsForVisibleRows) {
        if ((NSUInteger)path.row >= self.SaoqiangWCAssetsRows.count) continue;
        SaoqiangWCAssetsRecord *record = self.SaoqiangWCAssetsRows[path.row];
        BOOL selected = record.identity.length && self.SaoqiangWCAssetsSelected[record.identity] != nil;
        if (selected == [selectedPaths containsObject:path]) continue;
        if (selected) [table selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
        else [table deselectRowAtIndexPath:path animated:NO];
    }
}
- (void)SaoqiangWCAssetsUpdateSelection {
    NSUInteger count = self.SaoqiangWCAssetsSelected.count;
    BOOL master = SaoqiangWCAssetsMasterEnabled();
    BOOL capturing = SaoqiangWCAssetsIconCapturing();
    self.SaoqiangWCAssetsMasterSwitch.on = master;
    [self.SaoqiangWCAssetsStartButton setTitleColor:capturing ? UIColor.systemGreenColor : UIColor.labelColor forState:UIControlStateNormal];
    self.SaoqiangWCAssetsSummary.text = [NSString stringWithFormat:@"总开关%@ · 抓取%@ · 主题(始终开启) · 当前 %lu · SVG %lu · PNG %lu · 已选 %lu", master ? @"开" : @"关", capturing ? @"中" : @"停", (unsigned long)self.SaoqiangWCAssetsCurrentCount, (unsigned long)self.SaoqiangWCAssetsSVGCount, (unsigned long)self.SaoqiangWCAssetsPNGCount, (unsigned long)count];
    self.SaoqiangWCAssetsScopeLabel.text = [NSString stringWithFormat:@"作用列表：%@\n%lu 显示 · %lu 已选", @[@"当前", @"SVG", @"PNG", @"原生"][self.SaoqiangWCAssetsLastListFilter], (unsigned long)self.SaoqiangWCAssetsRows.count, (unsigned long)count];
    self.SaoqiangWCAssetsClearButton.enabled = !self.SaoqiangWCAssetsBusy;
    // 0.11.40: capture totals next to 清空. Counted over the same scope as the
    // 当前 list, so 总数 always matches what the table would show unfiltered.
    self.SaoqiangWCAssetsTotalValue.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.SaoqiangWCAssetsCurrentCount];
    self.SaoqiangWCAssetsPNGValue.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.SaoqiangWCAssetsPNGCount];
    self.SaoqiangWCAssetsSVGValue.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.SaoqiangWCAssetsSVGCount];
    self.SaoqiangWCAssetsNativeValue.text = [NSString stringWithFormat:@"%lu", (unsigned long)self.SaoqiangWCAssetsNativeCount];
    self.SaoqiangWCAssetsFilter.enabled = !self.SaoqiangWCAssetsBusy;
    self.SaoqiangWCAssetsThemeTabButton.enabled = !self.SaoqiangWCAssetsBusy;
    self.modalInPresentation = self.SaoqiangWCAssetsBusy;
    [self SaoqiangWCAssetsRefreshTheme];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate { if (!decelerate && self.SaoqiangWCAssetsPendingRefresh) [self SaoqiangWCAssetsRefresh:NO]; }
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView { if (self.SaoqiangWCAssetsPendingRefresh) [self SaoqiangWCAssetsRefresh:NO]; }
// Selection is now restored only for visible rows, so a row that scrolls in has
// to bring its own state with it.
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ((NSUInteger)indexPath.row >= self.SaoqiangWCAssetsRows.count) return;
    SaoqiangWCAssetsRecord *record = self.SaoqiangWCAssetsRows[indexPath.row];
    BOOL selected = record.identity.length && self.SaoqiangWCAssetsSelected[record.identity] != nil;
    cell.selected = selected;
    if (selected) [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    else [tableView deselectRowAtIndexPath:indexPath animated:NO];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.SaoqiangWCAssetsRows.count; }
- (void)SaoqiangWCAssetsBindCell:(SaoqiangWCAssetsCell *)cell record:(SaoqiangWCAssetsRecord *)record {
    NSString *name = SaoqiangWCAssetsHasOriginalName(record) ? record.name : @"无原始资源名";
    cell.SaoqiangWCAssetsName.text = name;
    cell.SaoqiangWCAssetsDetail.text = [NSString stringWithFormat:@"%@ · %g×%g pt%@", record.kind.uppercaseString ?: @"—", record.pointSize.width, record.pointSize.height, record.original ? @"" : @" · 快照"];
    [cell.SaoqiangWCAssetsPreview setImage:record.thumbnail ?: SaoqiangWCAssetsSymbol(@"photo") forState:UIControlStateNormal]; cell.SaoqiangWCAssetsPreview.tintColor = UIColor.secondaryLabelColor;
    cell.SaoqiangWCAssetsPreview.accessibilityLabel = [name stringByAppendingString:@"，详情与单项保存"];
    cell.SaoqiangWCAssetsCopy.accessibilityLabel = @"复制资源名"; __weak typeof(self) weakSelf = self;
    cell.SaoqiangWCAssetsCopyAction = ^{ [weakSelf SaoqiangWCAssetsCopyRecord:record]; };
    cell.SaoqiangWCAssetsPreviewAction = ^{ [weakSelf SaoqiangWCAssetsPreviewRecord:record]; };
    cell.SaoqiangWCAssetsContextAction = ^(BOOL open) {
        weakSelf.SaoqiangWCAssetsContextOpen = open; if (!open && weakSelf.SaoqiangWCAssetsPendingRefresh) [weakSelf SaoqiangWCAssetsRefresh:NO];
    };
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SaoqiangWCAssetsCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SaoqiangWCAssetsCell" forIndexPath:indexPath];
    [self SaoqiangWCAssetsBindCell:cell record:self.SaoqiangWCAssetsRows[indexPath.row]]; return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SaoqiangWCAssetsRecord *record = self.SaoqiangWCAssetsRows[indexPath.row];
    if (record.identity.length) self.SaoqiangWCAssetsSelected[record.identity] = record; [self SaoqiangWCAssetsUpdateSelection];
}
- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identity = self.SaoqiangWCAssetsRows[indexPath.row].identity;
    if (identity.length) [self.SaoqiangWCAssetsSelected removeObjectForKey:identity]; [self SaoqiangWCAssetsUpdateSelection];
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UINavigationController *nav = self.navigationController;
    // Edge/back gestures must start even over nav controls or while busy;
    // the UIControl filter below only guards the record long-press.
    if (gestureRecognizer == self.SaoqiangWCAssetsEdgePan ||
        (nav && gestureRecognizer == nav.interactivePopGestureRecognizer)) return YES;
    for (UIView *view = touch.view; view && view != self.SaoqiangWCAssetsTable; view = view.superview) if ([view isKindOfClass:UIControl.class]) return NO;
    return !self.SaoqiangWCAssetsBusy;
}
- (void)SaoqiangWCAssetsLongPressRow:(UILongPressGestureRecognizer *)press {
    if (press.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *path = [self.SaoqiangWCAssetsTable indexPathForRowAtPoint:[press locationInView:self.SaoqiangWCAssetsTable]];
    if (path && (NSUInteger)path.row < self.SaoqiangWCAssetsRows.count) [self SaoqiangWCAssetsPreviewRecord:self.SaoqiangWCAssetsRows[path.row]];
}
- (void)SaoqiangWCAssetsPreviewRecord:(SaoqiangWCAssetsRecord *)record {
    if (!self.view.window || self.presentedViewController || self.SaoqiangWCAssetsBusy) return;
    [self.view endEditing:YES]; SaoqiangWCAssetsPresentRecord(record, self);
}
- (void)SaoqiangWCAssetsCopyRecord:(SaoqiangWCAssetsRecord *)record {
    if (!SaoqiangWCAssetsHasOriginalName(record)) { [self SaoqiangWCAssetsAlert:@"无原始资源名" message:@"这项资源未取得真实名称，无法复制。可点缩略图查看或保存快照。"]; return; }
    UIPasteboard.generalPasteboard.string = record.name; [self SaoqiangWCAssetsToast:@"已复制资源名"];
}
- (void)SaoqiangWCAssetsSelectVisible {
    if (self.SaoqiangWCAssetsBusy) return; [self SaoqiangWCAssetsRefresh:NO]; BOOL all = self.SaoqiangWCAssetsRows.count > 0;
    for (SaoqiangWCAssetsRecord *record in self.SaoqiangWCAssetsRows) if (!record.identity.length || !self.SaoqiangWCAssetsSelected[record.identity]) { all = NO; break; }
    for (SaoqiangWCAssetsRecord *record in self.SaoqiangWCAssetsRows) if (record.identity.length) {
        if (all) [self.SaoqiangWCAssetsSelected removeObjectForKey:record.identity]; else self.SaoqiangWCAssetsSelected[record.identity] = record;
    }
    [self SaoqiangWCAssetsSyncSelection]; [self SaoqiangWCAssetsUpdateSelection];
}
- (void)SaoqiangWCAssetsToast:(NSString *)message {
    self.SaoqiangWCAssetsFeedback.text = [NSString stringWithFormat:@"  %@  ", message]; self.SaoqiangWCAssetsFeedback.hidden = NO;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message); NSUInteger generation = ++self.SaoqiangWCAssetsFeedbackGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (generation == self.SaoqiangWCAssetsFeedbackGeneration) self.SaoqiangWCAssetsFeedback.hidden = YES;
    });
}
- (void)SaoqiangWCAssetsAlert:(NSString *)title message:(NSString *)message {
    if (!self.view.window || self.presentedViewController) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    SaoqiangWCAssetsMarkOwnView(alert.view); [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)SaoqiangWCAssetsConfirmClear {
    if (self.SaoqiangWCAssetsBusy || self.presentedViewController) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空捕获？" message:@"将清空捕获记录和选择，已导出的文件不受影响。" preferredStyle:UIAlertControllerStyleAlert];
    SaoqiangWCAssetsMarkOwnView(alert.view); [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[SaoqiangWCAssetsStore SaoqiangWCAssetsShared] SaoqiangWCAssetsClear]; [self.SaoqiangWCAssetsSelected removeAllObjects]; [self SaoqiangWCAssetsRefresh:YES];
    }]]; [self presentViewController:alert animated:YES completion:nil];
}
- (void)SaoqiangWCAssetsExplainDirectory {
    if (self.SaoqiangWCAssetsBusy) return;
    [self SaoqiangWCAssetsAlert:@"导出目录" message:@"点击“导出所选”后，在系统“文件”中选择保存位置。完成保存后才会显示导出结果。"];
}
- (void)SaoqiangWCAssetsRefreshTheme {
    NSDictionary *state = SaoqiangWCAssetsThemePackState(); BOOL busy = SaoqiangWCAssetsThemeRequestPending || SaoqiangWCAssetsThemeRetrying || [state[@"busy"] boolValue];
    // 0.11.44: this runs on every tick and every selection change, but almost
    // always renders the same two strings. Assigning them anyway invalidated the
    // button and label layout each second, which is visible during a scroll.
    NSString *title = busy ? @"取消主题导出" : @"当前主题素材一键导出";
    if (![[self.SaoqiangWCAssetsThemeButton titleForState:UIControlStateNormal] isEqualToString:title])
        [self.SaoqiangWCAssetsThemeButton setTitle:title forState:UIControlStateNormal];
    BOOL enabled = !self.SaoqiangWCAssetsBusy && !(busy && SaoqiangWCAssetsThemeCancelRequested);
    if (self.SaoqiangWCAssetsThemeButton.enabled != enabled) self.SaoqiangWCAssetsThemeButton.enabled = enabled;
    NSString *progress;
    if (SaoqiangWCAssetsThemeRetrying) {
        progress = [NSString stringWithFormat:@"主题资源加载中，正在自动打包（第 %lu 次）…\n首次进入主题时资源延迟加载，稍候会自动完成，无需再次点击。", (unsigned long)(SaoqiangWCAssetsThemeEmptyRetries + 1)];
    } else if (busy) {
        progress = [NSString stringWithFormat:@"%@ · %@\n处理 %@ / %@ · 已导出 %@ · 未取到 %@ · 读取/写入失败 %@\n重名已保留 %@ · 格式提示 %@\n可关闭面板，返回工具页查看。", state[@"themeName"] ?: @"当前主题", SaoqiangWCAssetsThemeCancelRequested ? @"正在取消…" : (state[@"stage"] ?: @"定位主题"), state[@"processed"] ?: @0, state[@"total"] ?: state[@"expected"] ?: @0, state[@"written"] ?: @0, state[@"missing"] ?: @0, state[@"failed"] ?: @0, state[@"conflicts"] ?: @0, state[@"unsupported"] ?: @0];
    } else if ([SaoqiangWCAssetsLastThemeSummary[@"cancelled"] boolValue]) progress = @"已取消主题导出，可点上方按钮重试。";
    else if (SaoqiangWCAssetsLastThemeFolder && SaoqiangWCAssetsThemeAvailable(SaoqiangWCAssetsLastThemeSummary)) progress = [SaoqiangWCAssetsThemeReceipt(SaoqiangWCAssetsLastThemeSummary) stringByAppendingString:@"\n已导出文件可稍后点上方按钮保存或重新导出。"];
    else if (SaoqiangWCAssetsLastThemeSummary) progress = [SaoqiangWCAssetsThemeReceipt(SaoqiangWCAssetsLastThemeSummary) stringByAppendingString:@"\n暂无可保存文件，点上方按钮重试。"];
    else progress = @"点击上方按钮，自动读取当前微信主题内的全部素材并打包。\n完成后可选择保存到“文件”或直接分享。";
    if (![self.SaoqiangWCAssetsThemeProgress.text isEqualToString:progress]) self.SaoqiangWCAssetsThemeProgress.text = progress;
}
- (void)SaoqiangWCAssetsReferenceMenu {
    if(self.SaoqiangWCAssetsBusy||SaoqiangWCAssetsThemeRequestPending||[SaoqiangWCAssetsThemePackState()[@"busy"]boolValue]){[self SaoqiangWCAssetsToast:@"请先结束当前导出"];return;}
    NSDictionary *state=SaoqiangWCAssetsCurrentThemeReferenceState();
    if(state[@"error"]){[self SaoqiangWCAssetsAlert:@"当前主题不可用" message:state[@"error"]];return;}
    UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"当前主题对照清单" message:[NSString stringWithFormat:@"%@\n已导入 %@ 项。按原名主动读取，并逐项核对长度和SHA-256。清单只适用于相同主题ID；字节不同会拒绝保存。",state[@"themeName"],state[@"count"]] preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf=self;__weak UIAlertController *weakSheet=sheet;
    [sheet addAction:[UIAlertAction actionWithTitle:@"从文件导入 JSON 清单" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){SaoqiangWCAssetsAfterDismiss(weakSheet,^{
        typeof(self) owner=weakSelf;if(!owner)return;owner.SaoqiangWCAssetsBusy=YES;owner.SaoqiangWCAssetsPendingExport=@{@"referenceImport":@YES,@"themeID":state[@"themeID"]};
        UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeJSON] asCopy:YES];picker.delegate=owner;picker.allowsMultipleSelection=NO;
        [owner presentViewController:picker animated:YES completion:nil];
    });}]];
    if([state[@"count"]unsignedIntegerValue])[sheet addAction:[UIAlertAction actionWithTitle:@"移除当前主题清单" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a){SaoqiangWCAssetsAfterDismiss(weakSheet,^{
        NSString *error=nil;BOOL ok=SaoqiangWCAssetsClearCurrentThemeReference(&error);if(ok){SaoqiangWCAssetsLastThemeFolder=nil;SaoqiangWCAssetsLastThemeSummary=nil;}[weakSelf SaoqiangWCAssetsRefreshTheme];[weakSelf SaoqiangWCAssetsAlert:ok?@"已移除":@"无法移除" message:error?:@"当前主题将恢复按加载器已有清单导出"];
    });}]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView=self.SaoqiangWCAssetsThemeButton;sheet.popoverPresentationController.sourceRect=self.SaoqiangWCAssetsThemeButton.bounds;[self presentViewController:sheet animated:YES completion:nil];
}
- (void)SaoqiangWCAssetsExportTheme {
    if (self.SaoqiangWCAssetsBusy || self.presentedViewController || !self.view.window) return;
    if (SaoqiangWCAssetsThemeRequestPending || SaoqiangWCAssetsThemeRetrying || [SaoqiangWCAssetsThemePackState()[@"busy"] boolValue]) {
        SaoqiangWCAssetsThemeCancelRequested = YES; SaoqiangWCAssetsThemeRetrying = NO; SaoqiangWCAssetsThemeEmptyRetries = 0;
        SaoqiangWCAssetsCancelThemeExport(); [self SaoqiangWCAssetsRefreshTheme]; return;
    }
    if (SaoqiangWCAssetsLastThemeFolder && SaoqiangWCAssetsThemeAvailable(SaoqiangWCAssetsLastThemeSummary)) { [self SaoqiangWCAssetsPresentThemeFolder:SaoqiangWCAssetsLastThemeFolder summary:SaoqiangWCAssetsLastThemeSummary]; return; }
    // 用户主动点击：重置自动重试计数，开始新一轮。
    SaoqiangWCAssetsThemeEmptyRetries = 0;
    [self SaoqiangWCAssetsPerformThemeExport];
}
// 真正发起一次导出。空清单（主题资源尚未延迟加载完）时自动延时重试，避免用户手动点第二次。
- (void)SaoqiangWCAssetsPerformThemeExport {
    [self.view endEditing:YES]; SaoqiangWCAssetsThemeCancelRequested = NO; SaoqiangWCAssetsThemeRetrying = NO; SaoqiangWCAssetsThemeRequestPending = YES; SaoqiangWCAssetsLastThemeFolder = nil; SaoqiangWCAssetsLastThemeSummary = nil;
    [self SaoqiangWCAssetsRefreshTheme]; __weak typeof(self) weakSelf = self;
    SaoqiangWCAssetsExportCurrentTheme(^(NSURL *folder, NSDictionary *summary, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL cancelled = SaoqiangWCAssetsThemeCancelRequested || [summary[@"cancelled"] boolValue] || [SaoqiangWCAssetsThemePackState()[@"stage"] isEqual:@"已取消"];
            SaoqiangWCAssetsThemeRequestPending = NO; SaoqiangWCAssetsThemeCancelRequested = NO; SaoqiangWCAssetsThemeRetrying = NO;
            NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:summary ?: @{}];
            result[@"busy"] = @NO;
            if (error.length && ![result[@"diagnostic"] isEqualToString:error]) result[@"diagnostic"] = [result[@"diagnostic"] length] ? [NSString stringWithFormat:@"%@\n%@", result[@"diagnostic"], error] : error;
            if (cancelled) { result[@"cancelled"] = @YES; result[@"complete"] = @NO; result[@"available"] = @NO; }
            if (!folder) { result[@"complete"] = @NO; result[@"available"] = @NO; }
            BOOL available = folder && !cancelled && SaoqiangWCAssetsThemeAvailable(result);
            result[@"available"] = @(available);
            if (!available) {
                result[@"complete"] = @NO;
                if (!cancelled && ![result[@"diagnostic"] length]) result[@"diagnostic"] = @"未取得可保存的主题素材文件，请重试。";
            }
            SaoqiangWCAssetsLastThemeSummary = [result copy]; SaoqiangWCAssetsLastThemeFolder = available ? folder : nil;
            typeof(self) owner = weakSelf; [owner SaoqiangWCAssetsRefreshTheme];
            if (!owner.view.window || owner.isBeingDismissed || owner.presentedViewController) return;
            if (cancelled) { [owner SaoqiangWCAssetsToast:@"已取消主题导出"]; return; }
            if (available) { SaoqiangWCAssetsThemeEmptyRetries = 0; [owner SaoqiangWCAssetsPresentThemeFolder:folder summary:result]; return; }

            // 空清单：主题资源延迟加载尚未就绪。自动重试若干次，用户只需点一次。
            static NSUInteger const kMaxAutoRetries = 6;   // 6 次 × 1.2s ≈ 7.2s
            if (SaoqiangWCAssetsThemeEmptyRetries < kMaxAutoRetries) {
                SaoqiangWCAssetsThemeEmptyRetries++;
                SaoqiangWCAssetsThemeRetrying = YES;
                [owner SaoqiangWCAssetsRefreshTheme];
                __weak typeof(self) retrySelf = owner;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    typeof(self) next = retrySelf;
                    if (!next || !next.view.window || next.isBeingDismissed || next.presentedViewController) return;
                    if (SaoqiangWCAssetsThemeCancelRequested) return;
                    [next SaoqiangWCAssetsPerformThemeExport];
                });
                return;
            }
            // 重试耗尽仍为空：给出结果说明。
            SaoqiangWCAssetsThemeEmptyRetries = 0;
            [owner SaoqiangWCAssetsAlert:@"暂无可保存的主题素材" message:SaoqiangWCAssetsThemeReceipt(result)];
        });
    });
}
- (void)SaoqiangWCAssetsPresentThemeFolder:(NSURL *)folder summary:(NSDictionary *)summary {
    if (!self.view.window || self.presentedViewController || self.isBeingDismissed || self.SaoqiangWCAssetsBusy) return;
    if (SaoqiangWCAssetsThemeRequestPending || [SaoqiangWCAssetsThemePackState()[@"busy"] boolValue]) return;
    if (!folder || !SaoqiangWCAssetsThemeAvailable(summary)) { [self SaoqiangWCAssetsAlert:@"暂无可保存的主题素材" message:SaoqiangWCAssetsThemeReceipt(summary)]; return; }
    NSString *title = SaoqiangWCAssetsThemeComplete(summary) ? @"此次主题清单已全部导出" : @"已导出的主题素材可保存";
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title message:SaoqiangWCAssetsThemeReceipt(summary) preferredStyle:UIAlertControllerStyleActionSheet];
    SaoqiangWCAssetsMarkOwnView(sheet.view); __weak typeof(self) weakSelf = self; __weak UIAlertController *weakSheet = sheet;
    [sheet addAction:[UIAlertAction actionWithTitle:@"保存已导出文件到“文件”" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        SaoqiangWCAssetsAfterDismiss(weakSheet, ^{ [weakSelf SaoqiangWCAssetsSaveThemeFolder:folder summary:summary]; });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"分享已导出文件" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        SaoqiangWCAssetsAfterDismiss(weakSheet, ^{
            typeof(self) owner = weakSelf; if (!owner.view.window || owner.presentedViewController || owner.isBeingDismissed || owner.SaoqiangWCAssetsBusy || SaoqiangWCAssetsThemeRequestPending || [SaoqiangWCAssetsThemePackState()[@"busy"] boolValue] || !SaoqiangWCAssetsThemeAvailable(summary)) return;
            UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[folder] applicationActivities:nil];
            SaoqiangWCAssetsMarkOwnView(activity.view); activity.popoverPresentationController.sourceView = owner.SaoqiangWCAssetsThemeButton; activity.popoverPresentationController.sourceRect = owner.SaoqiangWCAssetsThemeButton.bounds;
            [owner presentViewController:activity animated:YES completion:nil];
        });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"重新导出当前主题" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        SaoqiangWCAssetsAfterDismiss(weakSheet, ^{ SaoqiangWCAssetsLastThemeFolder = nil; SaoqiangWCAssetsLastThemeSummary = nil; [weakSelf SaoqiangWCAssetsExportTheme]; });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"稍后保存" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.SaoqiangWCAssetsThemeButton; sheet.popoverPresentationController.sourceRect = self.SaoqiangWCAssetsThemeButton.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}
- (void)SaoqiangWCAssetsSaveThemeFolder:(NSURL *)folder summary:(NSDictionary *)summary {
    if (!self.view.window || self.presentedViewController || self.isBeingDismissed || self.SaoqiangWCAssetsBusy) return;
    if (SaoqiangWCAssetsThemeRequestPending || [SaoqiangWCAssetsThemePackState()[@"busy"] boolValue]) return;
    if (!folder || !SaoqiangWCAssetsThemeAvailable(summary)) { [self SaoqiangWCAssetsAlert:@"暂无可保存的主题素材" message:SaoqiangWCAssetsThemeReceipt(summary)]; return; }
    self.SaoqiangWCAssetsBusy = YES; self.SaoqiangWCAssetsPendingExport = @{@"wholeTheme":@YES, @"summary":summary}; [self SaoqiangWCAssetsUpdateSelection];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[folder] asCopy:YES];
    picker.delegate = self; picker.shouldShowFileExtensions = YES; picker.modalPresentationStyle = UIModalPresentationFormSheet;
    picker.modalInPresentation = YES; SaoqiangWCAssetsMarkOwnView(picker.view);
    picker.popoverPresentationController.sourceView = self.SaoqiangWCAssetsThemeButton; picker.popoverPresentationController.sourceRect = self.SaoqiangWCAssetsThemeButton.bounds;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)SaoqiangWCAssetsCopyDiagnostics {
    SaoqiangWCAssetsStore *store = [SaoqiangWCAssetsStore SaoqiangWCAssetsShared];
    UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"微信素材 0.11.4\n跨页累计：清空前保留\n抓取：%@\n%@\n\nSVG\n%@\n\n气泡\n%@\n\n整套主题状态\n%@\n结果\n%@", [store SaoqiangWCAssetsEnabled] ? @"开启" : @"停止", self.SaoqiangWCAssetsSummary.text ?: @"", SaoqiangWCAssetsSVGDiagnostics(), SaoqiangWCAssetsBubbleDiagnostics(), SaoqiangWCAssetsThemePackState(), SaoqiangWCAssetsLastThemeSummary ?: @{}];
    [self SaoqiangWCAssetsToast:@"已复制识别诊断"];
}
- (void)SaoqiangWCAssetsExportFolder {
    if (self.SaoqiangWCAssetsBusy || !self.view.window || self.presentedViewController) return;
    [self SaoqiangWCAssetsRefresh:NO]; NSArray *selected = [self.SaoqiangWCAssetsSelected.allValues sortedArrayUsingComparator:^NSComparisonResult(SaoqiangWCAssetsRecord *a, SaoqiangWCAssetsRecord *b) { return [a.identity compare:b.identity]; }];
    if (!selected.count) return;
    NSUInteger originals = 0, snapshots = 0, skipped = 0;
    for (SaoqiangWCAssetsRecord *record in selected) {
        if (!record.bytes.length) { skipped++; continue; } if (record.original) originals++; else snapshots++;
    }
    NSDictionary *receipt = @{@"originals":@(originals), @"snapshots":@(snapshots), @"skipped":@(skipped)};
    [self.view endEditing:YES]; self.SaoqiangWCAssetsBusy = YES; [self SaoqiangWCAssetsUpdateSelection];
    [[SaoqiangWCAssetsStore SaoqiangWCAssetsShared] SaoqiangWCAssetsExportFolder:selected completion:^(NSURL *url, NSString *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!url || error.length || !self.view.window || self.presentedViewController) {
                self.SaoqiangWCAssetsBusy = NO; [self SaoqiangWCAssetsUpdateSelection];
                if (!url || error.length) [self SaoqiangWCAssetsAlert:@"导出失败" message:error.length ? error : @"未能生成导出目录。"]; return;
            }
            self.SaoqiangWCAssetsPendingExport = receipt;
            UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[url] asCopy:YES];
            picker.delegate = self; picker.shouldShowFileExtensions = YES; picker.modalPresentationStyle = UIModalPresentationFormSheet;
            picker.modalInPresentation = YES; SaoqiangWCAssetsMarkOwnView(picker.view);
            picker.popoverPresentationController.sourceView = self.SaoqiangWCAssetsFolderButton; picker.popoverPresentationController.sourceRect = self.SaoqiangWCAssetsFolderButton.bounds;
            [self presentViewController:picker animated:YES completion:nil];
        });
    }];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSDictionary *receipt = self.SaoqiangWCAssetsPendingExport; self.SaoqiangWCAssetsPendingExport = nil;
    NSURL *destination = urls.firstObject;
    SaoqiangWCAssetsAfterDismiss(controller, ^{
        self.SaoqiangWCAssetsBusy = NO; [self SaoqiangWCAssetsUpdateSelection];
        if([receipt[@"referenceImport"]boolValue]){
            NSNumber *size=nil;NSError *e=nil;[destination getResourceValue:&size forKey:NSURLFileSizeKey error:&e];
            NSData *data=nil;NSString *reason=nil;BOOL ok=NO;
            if(!destination||e||size.unsignedLongLongValue>8*1024*1024)reason=@"无法读取JSON清单或文件超过8MB";
            else {data=[NSData dataWithContentsOfURL:destination options:0 error:&e];if(!data)reason=e.localizedDescription;else ok=SaoqiangWCAssetsImportCurrentThemeReference(data,receipt[@"themeID"],&reason);}
            if(ok){SaoqiangWCAssetsLastThemeFolder=nil;SaoqiangWCAssetsLastThemeSummary=nil;}[self SaoqiangWCAssetsRefreshTheme];
            NSDictionary *state=SaoqiangWCAssetsCurrentThemeReferenceState();[self SaoqiangWCAssetsAlert:ok?@"已导入对照清单":@"清单未导入" message:ok?[NSString stringWithFormat:@"%@ 项，点击当前主题素材一键导出开始逐项读取。",state[@"count"]]:reason?:@"读取失败"];return;
        }
        if (!destination || !receipt) { [self SaoqiangWCAssetsAlert:@"未确认保存" message:@"系统未返回保存位置，请在“文件”中检查。"]; return; }
        if ([receipt[@"wholeTheme"] boolValue]) {
            if (!SaoqiangWCAssetsThemeAvailable(receipt[@"summary"])) { [self SaoqiangWCAssetsAlert:@"主题素材状态已失效" message:SaoqiangWCAssetsThemeReceipt(receipt[@"summary"])]; return; }
            NSString *path = destination.isFileURL ? destination.path : destination.lastPathComponent;
            NSString *title = SaoqiangWCAssetsThemeComplete(receipt[@"summary"]) ? @"此次主题清单文件已保存" : @"已导出的主题素材已保存";
            [self SaoqiangWCAssetsAlert:title message:[NSString stringWithFormat:@"%@\n\n%@", SaoqiangWCAssetsThemeReceipt(receipt[@"summary"]), path ?: @"系统选择的位置"]]; return;
        }
        NSString *skipped = [receipt[@"skipped"] unsignedIntegerValue] ? [NSString stringWithFormat:@"\n无可用数据，跳过 %@ 项", receipt[@"skipped"]] : @"";
        NSString *path = destination.isFileURL ? destination.path : destination.lastPathComponent;
        [self SaoqiangWCAssetsAlert:@"导出结果" message:[NSString stringWithFormat:@"系统已确认保存文件夹。\n原图 %@ · 快照 %@%@\n\n%@", receipt[@"originals"], receipt[@"snapshots"], skipped, path ?: @"系统选择的位置"]];
    });
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    BOOL wholeTheme = [self.SaoqiangWCAssetsPendingExport[@"wholeTheme"] boolValue];
    self.SaoqiangWCAssetsPendingExport = nil;
    SaoqiangWCAssetsAfterDismiss(controller, ^{
        self.SaoqiangWCAssetsBusy = NO; [self SaoqiangWCAssetsUpdateSelection];
        [self SaoqiangWCAssetsToast:wholeTheme ? @"已取消保存，已导出的文件可稍后保存" : @"已取消保存"];
    });
}
@end

#pragma mark - 插件列表入口

// The floating button is gone: the panel is reached from WeChat's own third
// party plugin list. That page is provided by another injection, so nothing
// about it may be assumed except that it is a table whose title says 插件.
static char SaoqiangWCAssetsPluginEntryKey;
static char SaoqiangWCAssetsPluginHostKey;

// ThemeBox 3.0.8 registers itself into WCRefine's plugin hub through this API
// instead of rewriting the plugin page tableView. Reuse the same native path.
// If WCRefine is absent or changes its signature, the safe list-row fallback
// below still keeps 小扒手 reachable without touching the host's index model.
static BOOL SaoqiangWCAssetsPluginHubRegistered = NO;
static BOOL SaoqiangWCAssetsRegisterInPluginHub(void) {
    if (SaoqiangWCAssetsPluginHubRegistered) return YES;
    Class managerClass = NSClassFromString(@"WCRefinePluginHubManager");
    if (!managerClass || ![managerClass respondsToSelector:@selector(sharedInstance)]) return NO;
    id manager = [(id)managerClass performSelector:@selector(sharedInstance)];
    SEL selector = @selector(registerControllerWithTitle:version:controller:);
    if (!manager || ![manager respondsToSelector:selector]) return NO;
    NSMethodSignature *signature = [manager methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments < 5) return NO;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    if (!invocation) return NO;
    [invocation setSelector:selector];
    NSString *title = @"小扒手";
    NSString *version = SAOQIANG_WCASSETS_VERSION;
    NSString *controller = NSStringFromClass([SaoqiangWCAssetsController class]);
    [invocation setArgument:&title atIndex:2];
    [invocation setArgument:&version atIndex:3];
    [invocation setArgument:&controller atIndex:4];
    @try {
        [invocation invokeWithTarget:manager];
        SaoqiangWCAssetsPluginHubRegistered = YES;
        NSLog(@"[小扒手] 已通过原生 API 注册到 WCRefine 插件收纳");
        return YES;
    } @catch (NSException *exception) {
        (void)exception;
        return NO;
    }
}
static NSMutableDictionary<NSString *, NSValue *> *SaoqiangWCAssetsSelectOriginals;
static NSMutableDictionary<NSString *, NSValue *> *SaoqiangWCAssetsHeightOriginals;

@interface SaoqiangWCAssetsPluginEntry : NSObject <UITableViewDataSource>
@property(nonatomic,weak) id target;
@property(nonatomic,weak) UIViewController *host;
@property(nonatomic) NSInteger extraSection;
- (NSInteger)SaoqiangWCAssetsSections:(UITableView *)table;
- (void)SaoqiangWCAssetsBarAction:(id)sender;
@end

@implementation SaoqiangWCAssetsPluginEntry
- (NSInteger)SaoqiangWCAssetsSections:(UITableView *)table {
    if ([self.target respondsToSelector:@selector(numberOfSectionsInTableView:)])
        return [self.target numberOfSectionsInTableView:table];
    return 1;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return [self SaoqiangWCAssetsSections:table] + 1; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if (section == self.extraSection) return 1;
    return [self.target tableView:table numberOfRowsInSection:section];
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != self.extraSection) return [self.target tableView:table cellForRowAtIndexPath:indexPath];
    static NSString *identifier = @"SaoqiangWCAssetsPluginRow";
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
        cell.textLabel.text = @"小扒手";
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        cell.textLabel.textColor = UIColor.labelColor;
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        SaoqiangWCAssetsMarkOwnView(cell);
    }
    // Refreshed on every dequeue: the switch can be flipped while the panel is
    // open and the user comes back to this row without the page being rebuilt.
    cell.detailTextLabel.text = SAOQIANG_WCASSETS_VERSION;
    return cell;
}
- (BOOL)respondsToSelector:(SEL)selector {
    if ([super respondsToSelector:selector]) return YES;
    return [self.target respondsToSelector:selector];
}
- (id)forwardingTargetForSelector:(SEL)selector { return self.target; }
- (void)SaoqiangWCAssetsBarAction:(id)sender { (void)sender; SaoqiangWCAssetsPresentPanel(self.host); }
@end

static UITableView *SaoqiangWCAssetsFindTable(UIView *view, NSUInteger depth) {
    if (!view || depth > 12) return nil;
    if ([view isKindOfClass:UITableView.class]) return (UITableView *)view;
    for (UIView *child in view.subviews) {
        UITableView *found = SaoqiangWCAssetsFindTable(child, depth + 1);
        if (found) return found;
    }
    return nil;
}
static IMP SaoqiangWCAssetsOriginalIMP(NSMutableDictionary *map, id receiver) {
    return [map[NSStringFromClass(object_getClass(receiver))] pointerValue];
}
// One row is appended as an extra section, so every existing index stays put
// and the host's own model is never touched.
static void SaoqiangWCAssetsPluginSelect(id receiver, SEL cmd, UITableView *table, NSIndexPath *indexPath) {
    SaoqiangWCAssetsPluginEntry *entry = objc_getAssociatedObject(table, &SaoqiangWCAssetsPluginEntryKey);
    if (entry && indexPath.section == entry.extraSection) {
        // Drop the host's own selection highlight, then open our panel.
        [table deselectRowAtIndexPath:indexPath animated:YES];
        SaoqiangWCAssetsPresentPanel(entry.host);
        return;
    }
    IMP original = SaoqiangWCAssetsOriginalIMP(SaoqiangWCAssetsSelectOriginals, receiver);
    if (original) ((void (*)(id, SEL, UITableView *, NSIndexPath *))original)(receiver, cmd, table, indexPath);
}
static CGFloat SaoqiangWCAssetsPluginHeight(id receiver, SEL cmd, UITableView *table, NSIndexPath *indexPath) {
    SaoqiangWCAssetsPluginEntry *entry = objc_getAssociatedObject(table, &SaoqiangWCAssetsPluginEntryKey);
    if (entry && indexPath.section == entry.extraSection) return 52;
    IMP original = SaoqiangWCAssetsOriginalIMP(SaoqiangWCAssetsHeightOriginals, receiver);
    if (original) return ((CGFloat (*)(id, SEL, UITableView *, NSIndexPath *))original)(receiver, cmd, table, indexPath);
    return UITableViewAutomaticDimension;
}
static void SaoqiangWCAssetsReplaceForClass(Class cls, SEL selector, IMP replacement,
                                            NSMutableDictionary *originals, const char *fallbackTypes) {
    if (!cls || !selector || !originals) return;
    NSString *key = NSStringFromClass(cls);
    if (originals[key]) return;
    Method method = class_getInstanceMethod(cls, selector);
    IMP inherited = method ? method_getImplementation(method) : NULL;
    const char *types = method ? method_getTypeEncoding(method) : NULL;
    if (class_addMethod(cls, selector, replacement, types ?: fallbackTypes)) {
        if (inherited) originals[key] = [NSValue valueWithPointer:inherited];
    } else {
        Method own = class_getInstanceMethod(cls, selector);
        if (own) originals[key] = [NSValue valueWithPointer:method_setImplementation(own, replacement)];
    }
}
static void SaoqiangWCAssetsInstallDelegateHooks(UITableView *table, UIViewController *host) {
    if (!SaoqiangWCAssetsSelectOriginals) SaoqiangWCAssetsSelectOriginals = [NSMutableDictionary new];
    if (!SaoqiangWCAssetsHeightOriginals) SaoqiangWCAssetsHeightOriginals = [NSMutableDictionary new];
    // Installed on the delegate's own class, so the host keeps its logic and
    // only the extra section is intercepted; per-class map keeps it idempotent.
    Class delegateClass = table.delegate ? object_getClass(table.delegate) : object_getClass(host);
    SaoqiangWCAssetsReplaceForClass(delegateClass, @selector(tableView:didSelectRowAtIndexPath:),
                                    (IMP)SaoqiangWCAssetsPluginSelect, SaoqiangWCAssetsSelectOriginals, "v@:@@");
    SaoqiangWCAssetsReplaceForClass(delegateClass, @selector(tableView:heightForRowAtIndexPath:),
                                    (IMP)SaoqiangWCAssetsPluginHeight, SaoqiangWCAssetsHeightOriginals, "d@:@@");
}
static void SaoqiangWCAssetsInstallPluginEntry(UIViewController *host) {
    UITableView *table = SaoqiangWCAssetsFindTable(host.view, 0);
    id dataSource = table.dataSource;
    if (!table || !dataSource) {
        // Not a table-backed page (collection view or custom layout). Keep the
        // entry reachable from the navigation bar rather than losing it.
        if (objc_getAssociatedObject(host, &SaoqiangWCAssetsPluginHostKey)) return;
        if (host.navigationItem.rightBarButtonItem) return;
        SaoqiangWCAssetsPluginEntry *action = [SaoqiangWCAssetsPluginEntry new];
        action.host = host;
        objc_setAssociatedObject(host, &SaoqiangWCAssetsPluginHostKey, action, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        host.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"小扒手"
            style:UIBarButtonItemStylePlain target:action action:@selector(SaoqiangWCAssetsBarAction:)];
        return;
    }
    SaoqiangWCAssetsInstallDelegateHooks(table, host);
    SaoqiangWCAssetsPluginEntry *existing = objc_getAssociatedObject(table, &SaoqiangWCAssetsPluginEntryKey);
    if (existing) {
        // The host may reload the page with a fresh data source; keep our proxy
        // installed instead of losing the row on the second visit.
        if (existing.target != dataSource) existing.target = dataSource;
        existing.host = host;
        if (table.dataSource != existing) table.dataSource = existing;
        return;
    }
    SaoqiangWCAssetsPluginEntry *entry = [SaoqiangWCAssetsPluginEntry new];
    entry.target = dataSource; entry.host = host;
    entry.extraSection = [entry SaoqiangWCAssetsSections:table];
    objc_setAssociatedObject(table, &SaoqiangWCAssetsPluginEntryKey, entry, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    table.dataSource = entry;
    NSLog(@"[小扒手] 入口已装到 %@，第 %ld 节", NSStringFromClass(object_getClass(host)), (long)entry.extraSection);
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView performWithoutAnimation:^{ [table reloadData]; }];
    });
}
static BOOL SaoqiangWCAssetsPluginPage(UIViewController *controller) {
    // The title may be owned by the page or by a container that shows it.
    for (NSUInteger depth = 0; controller && depth < 3; ++depth) {
        NSString *title = controller.navigationItem.title ?: controller.title;
        if ([title isKindOfClass:NSString.class] && title.length) {
            NSString *trimmed = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if ([trimmed isEqualToString:@"插件"] || [trimmed isEqualToString:@"第三方插件"] ||
                [trimmed isEqualToString:@"微信插件"] || [trimmed containsString:@"第三方插件"]) return YES;
        }
        controller = controller.parentViewController;
    }
    return NO;
}
static IMP SaoqiangWCAssetsDidAppearOriginal;
// The title is the cheapest signal but not a reliable one: it can be owned by
// a container we never see. The rows on that page name the other injected
// extensions, and those strings exist nowhere else in the app, so they are a
// safe second opinion.
static BOOL SaoqiangWCAssetsPluginCell(UIView *view, NSUInteger depth) {
    if (!view || depth > 5) return NO;
    if ([view isKindOfClass:UILabel.class]) {
        NSString *text = ((UILabel *)view).text;
        return text.length && ([text containsString:@"主题盒子"] || [text containsString:@"WCRefine"]);
    }
    for (UIView *child in view.subviews) if (SaoqiangWCAssetsPluginCell(child, depth + 1)) return YES;
    return NO;
}
static BOOL SaoqiangWCAssetsPluginTable(UITableView *table) {
    for (UITableViewCell *cell in table.visibleCells) if (SaoqiangWCAssetsPluginCell(cell.contentView, 0)) return YES;
    return NO;
}
static void SaoqiangWCAssetsViewControllerDidAppear(id receiver, SEL cmd) {
    if (SaoqiangWCAssetsDidAppearOriginal) ((void (*)(id, SEL))SaoqiangWCAssetsDidAppearOriginal)(receiver, cmd);
    if (![receiver isKindOfClass:UIViewController.class]) return;
    UIViewController *controller = receiver;
    if (SaoqiangWCAssetsOwnUIActive()) return;
    if (!SaoqiangWCAssetsPluginPage(controller)) {
        UITableView *table = SaoqiangWCAssetsFindTable(controller.view, 0);
        if (!table || !SaoqiangWCAssetsPluginTable(table)) return;
    }
    // Native registration puts 小扒手 inside WCRefine's own plugin card.
    // No tableView mutation here means no index-shift crash and no covered
    // white border on the host's collection cell.
    if (SaoqiangWCAssetsRegisterInPluginHub()) return;
    SaoqiangWCAssetsInstallPluginEntry(controller);
}
static void SaoqiangWCAssetsInstallPluginListHook(void) {
    Method method = class_getInstanceMethod(UIViewController.class, @selector(viewDidAppear:));
    if (!method) return;
    SaoqiangWCAssetsDidAppearOriginal = method_setImplementation(method, (IMP)SaoqiangWCAssetsViewControllerDidAppear);
}

#pragma mark - 面板

static UIViewController *SaoqiangWCAssetsTopController(UIViewController *controller) {
    for (NSUInteger depth = 0; controller && depth < 32; ++depth) {
        if (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) { controller = controller.presentedViewController; continue; }
        if ([controller isKindOfClass:UINavigationController.class]) { UIViewController *next = ((UINavigationController *)controller).visibleViewController; if (next) { controller = next; continue; } }
        if ([controller isKindOfClass:UITabBarController.class]) { UIViewController *next = ((UITabBarController *)controller).selectedViewController; if (next) { controller = next; continue; } }
        if ([controller isKindOfClass:UISplitViewController.class]) { UIViewController *next = ((UISplitViewController *)controller).viewControllers.lastObject; if (next && next.view.window) { controller = next; continue; } }
        break;
    }
    return controller;
}
static UIWindow *SaoqiangWCAssetsKeyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows)
            if (window.isKeyWindow && window.windowLevel == UIWindowLevelNormal && !window.hidden) return window;
    }
    return nil;
}
// Drop whatever is underneath the panel back to the main WeChat tab (index 0)
// and reset that tab's navigation stack. Only public UIKit container classes
// are touched; on a host without a tab bar this is a no-op (safe in the test
// harness). Suppressed so the unwinding view traffic never feeds the hooks.
static void SaoqiangWCAssetsUnwindWeChatHome(UIViewController *anchor) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ SaoqiangWCAssetsUnwindWeChatHome(anchor); }); return;
    }
    UIWindow *window = anchor.view.window ?: SaoqiangWCAssetsKeyWindow();
    UITabBarController *tab = nil;
    for (UIViewController *c = anchor; c && !tab; c = c.presentingViewController)
        if ([c isKindOfClass:UITabBarController.class]) tab = (UITabBarController *)c;
    if (!tab) {
        UIViewController *cursor = window.rootViewController;
        for (NSUInteger depth = 0; cursor && depth < 32; ++depth) {
            if ([cursor isKindOfClass:UITabBarController.class]) { tab = (UITabBarController *)cursor; break; }
            if (cursor.presentedViewController && !cursor.presentedViewController.isBeingDismissed) { cursor = cursor.presentedViewController; continue; }
            if ([cursor isKindOfClass:UINavigationController.class] && ((UINavigationController *)cursor).visibleViewController) { cursor = ((UINavigationController *)cursor).visibleViewController; continue; }
            break;
        }
    }
    if (!tab) return;
    SaoqiangWCAssetsPushSuppression();
    @try {
        UIViewController *modal = tab.presentedViewController;
        if (modal && !modal.isBeingDismissed) [tab dismissViewControllerAnimated:NO completion:nil];
        tab.selectedIndex = 0;
        UIViewController *selected = tab.selectedViewController;
        UIViewController *visible = selected;
        if ([selected isKindOfClass:UINavigationController.class]) visible = ((UINavigationController *)selected).visibleViewController ?: selected;
        UIViewController *nested = visible.presentedViewController;
        if (nested && !nested.isBeingDismissed) [visible dismissViewControllerAnimated:NO completion:nil];
        if ([selected isKindOfClass:UINavigationController.class])
            [((UINavigationController *)selected) popToRootViewControllerAnimated:NO];
    } @finally { SaoqiangWCAssetsPopSuppression(); }
}
static void SaoqiangWCAssetsPresentPanelAtPage(UIViewController *presenter, NSInteger initialPage, BOOL sheet) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ SaoqiangWCAssetsPresentPanelAtPage(presenter, initialPage, sheet); }); return;
    }
    if (SaoqiangWCAssetsOwnUIActive()) return;
    UIWindow *window = presenter.view.window ?: SaoqiangWCAssetsKeyWindow();
    UIViewController *top = presenter.view.window ? presenter : SaoqiangWCAssetsTopController(window.rootViewController);
    if (!top.view.window || top.isBeingDismissed || top.isBeingPresented || top.presentedViewController ||
        [top isKindOfClass:UIAlertController.class]) return;
    // Capture before suppression/presentation, while the host page is visible.
    if ([[SaoqiangWCAssetsStore SaoqiangWCAssetsShared] SaoqiangWCAssetsEnabled]) SaoqiangWCAssetsCaptureVisiblePage();
    SaoqiangWCAssetsPushSuppression();
    @try {
        SaoqiangWCAssetsController *controller = [SaoqiangWCAssetsController new];
        // 0.11.38: present inside a navigation controller. The panel carries its
        // only exit affordance in navigationItem.leftBarButtonItem (the ‹
        // chevron), and a navigation item is only rendered by a navigation bar.
        // Presenting the bare controller (what the two/three-finger shortcut
        // did) gave a full-screen panel with no bar at all, so the user could
        // summon the panel but never leave it. With this wrapper the shortcut
        // path looks exactly like the normal plugin-hub entry.
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
        // Full screen: no floating sheet and no empty gap above the panel.
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        nav.navigationBarHidden = NO;
        // 0.11.42: an opaque bar. A translucent bar lets the panel content slide
        // underneath it, and in the card host the child safe area is not reliable
        // enough to compensate — that is exactly how the 20pt page titles ended
        // up half-covered on device.
        nav.navigationBar.translucent = NO;
        if (@available(iOS 13.0, *)) {
            UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
            [appearance configureWithOpaqueBackground];
            appearance.backgroundColor = SaoqiangWCAssetsCanvas();
            appearance.shadowColor = UIColor.clearColor;
            nav.navigationBar.standardAppearance = appearance;
            nav.navigationBar.scrollEdgeAppearance = appearance;
            nav.navigationBar.compactAppearance = appearance;
        }
        nav.presentationController.delegate = controller;
        SaoqiangWCAssetsPresentedController = controller;
        SaoqiangWCAssetsMarkOwnView(nav.view);
        SaoqiangWCAssetsMarkOwnView(controller.view);
        // 0.11.40: the gesture shortcut opens the panel as a 3/5 bottom card
        // instead of a full-screen take-over, so WeChat stays visible behind it.
        // The plugin-hub entry keeps the old full-screen presentation.
        UIViewController *presented = nav;
        if (sheet) {
            SaoqiangWCAssetsSheetHost *host = [[SaoqiangWCAssetsSheetHost alloc] initWithNavigation:nav];
            host.modalPresentationStyle = UIModalPresentationOverFullScreen;
            SaoqiangWCAssetsMarkOwnView(host.view);
            controller.SaoqiangWCAssetsSheet = host;
            presented = host;
        }
        // 0.11.39: switch to the shortcut's page while the panel is still off
        // screen, so the first frame the user sees is already the icon/theme
        // page. Doing it in the presentation completion showed the home page
        // for the whole 0.35s present animation first.
        if (initialPage != 0) {
            [controller loadViewIfNeeded];
            controller.SaoqiangWCAssetsSkipPageAnimation = YES;
            [controller SaoqiangWCAssetsShowPage:initialPage];
            controller.SaoqiangWCAssetsSkipPageAnimation = NO;
        }
        [top presentViewController:presented animated:YES completion:^{
            // Fallback only: if something reset the page while presenting, land
            // on the requested one without a transition.
            if (initialPage != 0 && SaoqiangWCAssetsPresentedController == controller && controller.SaoqiangWCAssetsPage == 0) {
                controller.SaoqiangWCAssetsSkipPageAnimation = YES;
                [controller SaoqiangWCAssetsShowPage:initialPage];
                controller.SaoqiangWCAssetsSkipPageAnimation = NO;
            }
        }];
    } @finally { SaoqiangWCAssetsPopSuppression(); }
}
void SaoqiangWCAssetsPresentPanel(UIViewController *presenter) {
    SaoqiangWCAssetsPresentPanelAtPage(presenter, 0, NO);
}
#ifdef SAOQIANG_WCASSETS_TESTING
// Test-only: open the gesture card exactly like the two/three-finger shortcut,
// so the simulator smoke check can assert the 3/5 sheet layout without WeChat.
void SaoqiangWCAssetsPresentPanelForTesting(UIViewController *presenter, NSInteger page, BOOL sheet) {
    SaoqiangWCAssetsPresentPanelAtPage(presenter, page, sheet);
}
#endif
static void SaoqiangWCAssetsPresentIconPage(void) {
    SaoqiangWCAssetsPresentPanelAtPage(nil, 1, YES);
}
static void SaoqiangWCAssetsPresentThemePage(void) {
    SaoqiangWCAssetsPresentPanelAtPage(nil, 2, YES);
}
void SaoqiangWCAssetsInstallUI(void) {
#if !TARGET_OS_SIMULATOR
    if (![[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"] isEqualToString:@"WeChat"]) return;
#endif
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SaoqiangWCAssetsInstallPluginListHook();
        // WCRefine may finish loading slightly after this dylib. Register once
        // on the next main-queue turn as well; the plugin-page hook below is
        // still there in case WCRefine was not loaded yet at this point.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SaoqiangWCAssetsRegisterInPluginHub();
        });
        // The stored switches survive an upgrade, but the store starts stopped.
        // Without this the panel reads 开 while nothing is ever captured.
        SaoqiangWCAssetsSyncCapture();
        // Two-finger hold -> icon page, three-finger hold -> theme page.
        // Installed at the UIWindow sendEvent: level, so it works on every
        // WeChat screen regardless of the key window or gesture conflicts.
        SaoqiangWCAssetsInstallGlobalPress();
    });
}
