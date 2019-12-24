
#' Set the envi Package Path
#'
#' @param path the new envi package path.
#' @export
set_envi_path <- function(path) {
  if (missing(path)) {
    # Set the path to the default location.
    path <- file.path(path.expand("~"), ".envi")
  }
  tryCatch({
    if (!dir.exists(path)) {
      dir.create(path)
    }
    assign("path", path, pos = envi_globals, inherits = FALSE)
    invisible(TRUE)
  }, error = function(e) {
    if (exists("path", where = envi_globals, inherits = FALSE)) {
      remove("path", envir = envi_globals)
    }
    e
  })
}

#' Get the Absolute envi Package Path
#'
#' @export
get_envi_path <- function() {
  if (!exists("path", where = envi_globals, inherits = FALSE)) {
    # Use the default location.
    set_envi_path()
  }
  envi_globals$path
}

#' List the Current Available Environments
#'
#' @importFrom tibble tibble
#' @importFrom crayon yellow
#' @export
envi_list <- function() {
  if ( !dir.exists(get_envi_path()) ) {
    warning(yellow("No environments available."))
    tibble(handle = character(), path = character())
  } else {
    if (!file.exists(file.path(get_envi_path(), "environments.rds"))) {
      tibble(handle = character(), path = character())
    } else {
      readRDS(file.path(get_envi_path(), "environments.rds"))
    }
  }
}

#' Get an Environments Packages and Versions
#' 
#' @param handle the handle of the environment to get the package list for.
#' @export
envi_packages <- function(handle) {
  # call dir use desc package
}

#' Get the path to an Environment
#'
#' @param handle the handle of the environment. If missing, all paths are 
#' returned. Default is the current, activated environment handle, or NULL
#' if one is not activated.
#' @export
envi_env_path <- function(handle = envi_current_handle()) {
  if (is.null(handle) || is.na(handle)) {
    NULL
  } else {
    l <- envi_list()
    if (!missing(handle)) {
      file.path(get_envi_path(), "environments", 
                basename(l$path[l$handle == handle]))
    } else {
      file.path(get_envi_path(), 
                "environments", 
                basename(l$path[l$handle == handle]))
    }
  }
}

#' Activate an Environment
#'
#' @param handle the environment handle.
#' @export
envi_activate <- function(handle) {
  check_renv_installed()
  deactivate_if_activated()
  renv::activate(envi_env_path(handle))
  invisible(TRUE)
}

#' Deactivate an Environment
#'
#' @param snapshot should a snapshot be created on exit? (Default TRUE)
#' @param confirm should the user be prompted before taking action? 
#' (Default interactive()).
#' @param force should the lockfile be generated even when preflight validation
#' check have failed? (Default FALSE)
#' @export
envi_deactivate <- function(snapshot = TRUE, confirm = interactive(), 
                            force = FALSE) {
  if (is.null(envi_current_handle())) {
    warning(yellow("No activated environment.`"))
    invisible(FALSE)
  } else {
    renv::snapshot(envi_env_path(), confirm = confirm, force = force)
    renv::deactivate(envi_env_path())
    set_current_handle(NULL)
    invisible(TRUE)
  }
}

#' Create an R Environment
#'
#' @param handle the name of the new environment.
#' @param full_name the name of the environment directory. (Defalt is the
#' value of the handle argument)
#' @param bare should the project be initialized without attempting to 
#' discover and install R package dependencies? (Default TRUE)
#' @param git_init project include an initialized git repository? 
#' (Default TRUE)
#' @importFrom git2r init
#' @importFrom crayon red yellow
#' @export
envi_create <- function(handle, full_name = handle, bare = FALSE, 
                        git_init = TRUE) {
  l <- envi_list()
  if (nrow(l) > 0 && 
      (handle %in% l$handle || 
       full_name %in% vapply(l$handle, basename, NA_character_))) {
    
    stop(red("The handle or full name is already in use."))
  }
  check_renv_installed()
  new_env_path <- file.path(get_envi_path(), "environments", full_name)
  cwd <- getwd()
  deactivate_if_activated()
  renv::init(new_env_path, bare = bare, restart = FALSE)
  if (git_init) {
    renv::hydrate("git2r")
    git2r::init(new_env_path)
  }
  setwd(cwd)
  renv::hydrate(c("utf8", "vctrs"))
  l <- envi_list()
  l <- rbind(l, 
             tibble(handle = handle, 
                    path = file.path(get_envi_path(), "environments", 
                                     full_name)))
  write_config(l, file.path(get_envi_path(), "environments.rds"))
  set_current_handle(handle)
  invisible(TRUE)
}

#' Clone an R Environment
#'
#' @param path the path of the repository housing the R environment to clone.
#' @param handle the handle for the new environment.
#' @param verbose should extra information be printed? (Default TRUE)
#' @param progress should the progress of the clone be shown? (Default verbose)
#' @importFrom git2r clone
#' @importFrom crayon red
#' @export
envi_clone  <- function(path, handle = basename(path), 
                        verbose = TRUE, progress = verbose) {
  l <- envi_list()
  if (handle %in% l$handle) {
    stop(red("The handle is already in use. Note that for local source", 
             "repositories you must supply a unique handle"))
  }
  env_path <- file.path(get_envi_path(), "environments")
  if (!dir.exists(env_path)) {
    dir.create(env_path)
  }
  env_path <- file.path(env_path, handle)
  deactivate_if_activated()
  if (verbose) {
    cat("Cloning the repository")
  }
  clone(path, env_path, progress = verbose)
  # Does it look like an environment?
  if (!looks_like_r_environment(env_path)) {
    warning(
      yellow( 
        "Repository doesn't look like an renv object. It is being removed."))
    unlink(env_path, recursive = TRUE, force = TRUE)
    FALSE
  } else {
    l <- rbind(l, tibble(handle = handle, path = path))
    write_config(l, file.path(get_envi_path(), "environments.rds"))
    invisible(TRUE)
  }
}

#' Uninstall an Environment
#'
#' @param handle the environment handle.
#' @param ask should the user be prompted before removing the environment?
#' (Default TRUE)
#' @param purge should all files in the environments directory be removed?
#' (Default TRUE)
#' @export
envi_uninstall <- function(handle, ask = TRUE, purge = TRUE) {
  # If the handle is active then deactivate.

  # Unlink the environments directory.
}

#' Remove envi Configuration and Environments
#' 
#' @param ask should the user be prompted to make sure they want to purge
#' all envi environments? (Default TRUE)
#' @param remove_internal_vars should the envi-internal environment be removed?
#' (Default TRUE)
#' @importFrom crayon red
purge_envi <- function(ask = TRUE, remove_internal_vars = TRUE) {
  if (ask) {
    resp <- askYesNo(red("This will remove your envi environments and",
                         "cannot be undone. Are you sure you want to do",
                         "this?"))
  } else {
    resp <- TRUE
  }
  if (isTRUE(resp)) {
    # TODO purge the environment.

    # Deactivate the current environment.

    # Remove the global variables

    # Unlink the ~/.envi directory with prejudice and abandon.
    unlink("~/.envi", recursive = TRUE, force = TRUE)
  } else {
    FALSE
  }
}

#' Get the Handle of the Current Environment
#'
#' @export
envi_current_handle <- function() {
  if (exists("handle", where = envi_globals, inherits = FALSE)) {
    envi_globals$handle
  } else {
    NULL
  }
}

#' Log an Environment's Packages
#'
#' @param x a envi log object.
#' @param handle the environment handle.
#' @export
envi_log <- function(x, handle = envi_current_handle()) {
}

#' Save the Package Log
#'
#' @param pkg_log the package log.
#' @param location the location where the log should be saved. 
#' (Default ~/.envi/package-log.rds)
#' @export
envi_save_log <- function(pkg_log, 
  location = file.path(get_envi_path(), "package-log.rds")) {
}

#' Checkpoint the Current Package Configuration
#'
#' @param handle the handle to the envronment you'd like to checkpoint.
#' @export
envi_checkpoint <- function(handle = envi_current_handle()) {
}

#' Reset a Remote Environment
#'
#' @param handle the environment handle.
#' @param clean should file that are not part of the repository be removed?
#' (Default FALSE)
#' @export
envi_hard_reset <- function(handle, clean = FALSE) {
  # WARNING: do note this deletes untracked files
  #status() %>%
  #  purrr::pluck("untracked") %>%
  #  rlang::flatten_chr() %>%
  #  unlink()
}
