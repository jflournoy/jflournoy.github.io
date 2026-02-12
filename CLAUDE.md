# Project Notes

## Rendering

To render Quarto documents (`.qmd`) in this project, use the `jflournoy/verse-cmdstan` Docker container with `/home/rstudio` as the home directory:

```bash
docker run --rm -v /home/jflournoy/code/johnflournoy.science:/home/rstudio/code/johnflournoy.science -w /home/rstudio/code/johnflournoy.science jflournoy/verse-cmdstan bash -c 'tlmgr option repository https://mirror.ctan.org/systems/texlive/tlnet && tlmgr update --self && tlmgr install fontawesome5 enumitem changepage sectsty && quarto render <file.qmd>'
```

Note: The TeX Live packages need to be installed each run since the container is ephemeral (`--rm`). The `tlmgr update --self` is needed when the CTAN mirror has a newer tlmgr than the container image.
