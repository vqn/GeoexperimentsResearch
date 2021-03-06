# Copyright 2016 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Compose text strings conditional on values of an object.
#'
#' @param x an integer-valued numeric scalar or a logical vector. In the former
#'   case, indicates a number of items; in the latter case, indicates
#'   which items in a vector were affected. May have the 'names' attribute
#'   set.
#' @param ... one or more character vectors that are pasted together
#'   (collapsed) after concatenating the vectors one after another.
#' @param quote the quote character to use.
#'
#' @return A character string.
#'
#' @details
#' The function replaces the following special character patterns:
#' \itemize{
#'   \item{\code{\{a|b}\}}: 'a' if \code{sum(x) == 1} and 'b' otherwise.
#'   \item{\code{\{z|a|b\}}}: 'z' if \code{sum(x) == 0}, otherwise works
#'     like \code{{a|b}}.
#'   \item{\code{$N}}: \code{sum(x)}.
#'   \item{\code{$P}}: \code{sprintf("\%.1f", 100 * mean(x))}.
#'   \item{\code{$L}}: \code{length(x)}. The following patterns are
#'     replaced with comma-separated lists of:
#'   \itemize{
#'     \item{\code{$w}}: \code{which(x)}.
#'     \item{\code{$W}}: \code{which(x)}, each item quoted.
#'     \item{\code{$x}}: \code{names(x)[which(x)]}.
#'     \item{\code{$X}}: \code{names(x)[which(x)]}, each item quoted.
#'   }
#' }
#'
#' Exception: These four patterns output only up to the Kth item, where
#' \code{K = getOption('FormatTextMaxOutput', default=7L)}.
#'
#' @examples
#' \dontrun{
#'   FormatText(n, "There {is|are} {no|one|$N} item{|s}.")
#'   FormatText(is.na(x), "Found $N NAs ($P% of all $L) in rows $w")}

FormatText <- function(x, ..., quote="'") {
  assert_that((is.integer.valued(x) && x >= 0L) || is.logical(x),
              !anyNA(x),
              msg=paste0("'x' must be an integer-valued scalar ",
                         "or a logical vector with no NAs"))
  v <- as.character(unlist(list(...)))
  assert_that(length(v) > 0L,
              msg="One or more character vectors expected for '...'")
  txt <- paste0(v, collapse="")
  n <- sum(x)
  max.output <- getOption("FormatTextMaxOutput", default=7L)
  .W <- function(quote="") {
    function() {
      w <- which(x)
      ConcatItems(w, quote=quote, max.output=max.output)
    }
  }
  .X <- function(quote="") {
    function() {
      assert_that(is.vector.of.nonempty.strings(names(x)),
                  msg="'x' must have the names attribute set")
      w <- names(x)[x]
      ConcatItems(w, quote=quote, max.output=max.output)
    }
  }
  rgx.list <- list("\\{([^|]*)\\|([^|]*)\\}"=ifelse(n == 1, "\\1", "\\2"),
                   "\\{([^|]*)\\|([^|]*)\\|([^|]*)\\}"=ifelse(
                       n == 0, "\\1", ifelse(n == 1, "\\2", "\\3")),
                   "\\$N"=paste(n),
                   "\\$L"=paste(length(x)),
                   "\\$P"=sprintf("%.1f", 100 * mean(x)),
                   "\\$w"=.W(),
                   "\\$W"=.W(quote="'"),
                   "\\$x"=.X(),
                   "\\$X"=.X(quote="'"))
  for (i in seq_along(rgx.list)) {
    rgx <- names(rgx.list)[[i]]
    repl <- rgx.list[[i]]
    if (any(grepl(rgx, txt))) {
      if (is.function(repl)) {
        assert_that(is.logical(x),
                    msg=paste0("'x' must be logical to use the pattern ", rgx))
        repl <- repl()
      }
      txt <- gsub(rgx, replacement=repl, x=txt)
    }
  }
  return(txt)
}

#' Concatenate items of a vector, optionally quoting each.
#'
#' @param x (atomic vector) an atomic vector, coerced to character.
#' @param quote (string) a quote character to use.
#' @param collapse (string) string to use for collapsing the components of 'x'.
#' @param max.output (integer) maximum number of items of 'x' to output.
#'
#' @return A string.

ConcatItems <- function(x, quote="'", collapse=", ", max.output=Inf) {
  assert_that(is.atomic(x), !is.null(x))
  assert_that(is.string(quote))
  assert_that(is.string(collapse))
  assert_that(max.output %in% Inf || is.count(max.output))
  n <- length(x)
  if (n == 0L) {
    txt <- ""
  } else {
    if (max.output < n - 1L) {
      x <- x[seq_len(max.output)]
    }
    txt <- paste0(quote, paste(x), quote, collapse=collapse)
    if (max.output < n - 1L) {
      txt <- paste0(txt, ", ...")
    }
  }
  return(txt)
}
