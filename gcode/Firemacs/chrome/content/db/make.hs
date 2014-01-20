module Make where

import Control.Applicative hiding (many)
import Data.List
import Text.Parsec
import Text.Parsec.String

----------------------------------------------------------------

threshold :: Int
threshold = 13 -- height of column

input,template,output1,output2,output3 :: String
input    =    "firemacs.yml"
template =    "config.xul"
output1  = "../config-name.js"
output2  = "../keybinding.js"
output3  = "../config.xul"

header :: String
header = "////////////////////////////////////////////////////////////////\n"
      ++ "//\n"
      ++ "// Automatically generated by Haskell with YML\n"
      ++ "//\n"
      ++ "\n"

----------------------------------------------------------------

main :: IO ()
main = do
    lst <- parseYml <$> readFile input
    msg output1
    makeFile1 output1 lst
    done
    msg output2
    makeFile2 output2 lst
    done
    msg output3
    tmp <- readFile template
    makeFile3 output3 tmp lst
    done
  where
    msg file = putStr $ "Generating \"" ++ file ++ "\"... "
    done = putStrLn "done"

----------------------------------------------------------------

makeFile1 :: FilePath -> [DATA] -> IO ()
makeFile1 file lst = writeFile file $ makeContents1 lst

makeContents1 :: [DATA] -> String
makeContents1 lst = header
                 ++ "FmxConfig._names = [\n"
                 ++ nonbool lst
                 ++ "];\n"
                 ++ "\n"
                 ++ "FmxConfig._boolNames = [\n"
                 ++ bool lst
                 ++ "];\n"
  where
    addPrefix str = "  '" ++ str ++ "'"
    nonbool = jsArray . map (addPrefix.name) . filter (not.isBool)
    bool    = jsArray . map (addPrefix.name) . filter isBool

----------------------------------------------------------------

makeFile2 :: FilePath -> [DATA] -> IO ()
makeFile2 file lst = writeFile file $ makeContents2 lst

keyGroup :: [String]
keyGroup = ["View", "Edit", "Common", "Menu"]

allGroup :: [String]
allGroup  = "Option" : keyGroup

makeContents2 :: [DATA] -> String
makeContents2 lst = header
                 ++ "Firemacs.Commands = {};\n"
                 ++ "\n"
                 ++ command keyGroup lst
                 ++ "Firemacs.CmdKey = {};\n"
                 ++ "\n"
                 ++ cmdKey allGroup lst

command :: [String] -> [DATA] -> String
command keygroup lst = concatMap eachGroup keygroup
  where
    eachGroup gName = jsObj $ filter (\ent -> grp ent == gName) lst
      where
        jsObj l = "Firemacs.Commands." ++ gName ++ " = {\n"
               ++ jsArray (map jsFunc l)
               ++ "};\n"
               ++ "\n"
        jsFunc ent = "    " ++ name ent ++ ": function(e) {\n"
                  ++ "        " ++ body ent ++ "\n"
                  ++ "    }"

cmdKey :: [String] -> [DATA] -> String
cmdKey allgroup lst = concatMap eachGroup allgroup
  where
    eachGroup gName = jsObj $ filter (\ent -> grp ent == gName) lst
      where
        jsObj l = "Firemacs.CmdKey." ++ gName ++ " = {\n"
               ++ jsArray (map jsHash l)
               ++ "};\n"
               ++ "\n"
        jsHash ent = "    " ++ name ent ++ ": " ++ jsKey (key ent)
        jsKey "true"  = "true"
        jsKey "false" = "false"
        jsKey str     = "'" ++ str ++ "'"

----------------------------------------------------------------

makeFile3 :: FilePath -> String -> [DATA] -> IO ()
makeFile3 file tmp lst = writeFile file . replace . makeContents3 $ lst
  where
    replace r = unlines . concatMap repl . lines $ tmp
      where
        repl "$tabpanels$" = lines r
        repl str = [str]

indentWith :: String -> String -> String
indentWith prefix str = unlines . map (prefix ++) . lines $ str

indent :: String -> String
indent = indentWith "  "

getOpts :: [(String, String)] -> String
getOpts lot = concatMap keyVal lot
  where
    keyVal (k, v) = " " ++ k ++ "=\"" ++ escape v ++ "\""
    escape value = concatMap repl value
    repl '<' = "&lt;"
    repl '>' = "&gt;"
    repl c   = [c]

dtag :: String -> [(String, String)] -> String -> String
dtag nm opts cont = open ++ indent cont ++ close
    where
      open  = "<" ++ nm ++ getOpts opts ++ ">\n"
      close = "</" ++ nm ++ ">\n"

stag :: String -> [(String, String)] -> String
stag nm opts = "<" ++ nm ++ getOpts opts ++ " />\n"

makeContents3 :: [DATA] -> String
makeContents3 lst = tabpanels
  where
    tabpanels  = indentWith "    " $ concatMap tabpanel allGroup
    tabpanel g = dtag "tabpanel" [("equalsize","always")] $ grids g

    grids g = let ents = filter (\ent -> grp ent == g) lst
              in grid ents

    grid [] = ""
    grid ents = gridtag ++ loop
      where
        hd = take threshold ents
        tl = drop threshold ents
        gridtag = dtag "grid" [("flex","1")] (columns ++ rows hd)
        loop = grid tl

    columns = dtag "columns" [] (column ++ column)
    column = stag "column" []

    rows slst = dtag "rows" [] $ concatMap row slst
    row ent = dtag "row" [] $ box ent ++ description ent
    box ent = if isBool ent
              then checkbox ent
              else textbox ent
    textbox ent = stag "textbox" [("id",name ent),("value",key ent)]
    checkbox ent = stag "checkbox" [("id",name ent),("checked",key ent)]
    description ent = stag "description" [("value",desc ent)]

----------------------------------------------------------------

jsArray :: [String] -> String
jsArray lst = concat (intersperse ",\n" lst) ++ "\n"

----------------------------------------------------------------

data DATA = DATA {
    name :: String
  , grp  :: String
  , key  :: String
  , body :: String
  , desc :: String
  , dtype :: String
  }

isBool :: DATA -> Bool
isBool dat = dtype dat == "boolean"

----------------------------------------------------------------

parseYml :: String -> [DATA]
parseYml cs = case parse yml "" cs of
    Right lst -> lst
    Left _    -> error "parseYml"

yml :: Parser [DATA]
yml = many block

block :: Parser DATA
block = separator >> (lst2tuple <$> many keyval)
  where
    lst2tuple [a, b, c, d, e, f] = DATA a b c d e f
    lst2tuple _ = error "lst2tuple"

separator :: Parser ()
separator = char '-' >> eol

keyval :: Parser String
keyval = (many1 letter >> string ": ") *> (many (noneOf "\n") <* eol)

eol :: Parser ()
eol = () <$ char '\n'