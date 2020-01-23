module Payload.Docs.ToJsonSchema where

import Prelude

import Control.Alt ((<|>))
import Data.Array as Array
import Data.List (List)
import Data.List as List
import Data.Maybe (Maybe(..), fromMaybe)
import Data.String (Pattern(..), Replacement(..))
import Data.String as String
import Data.Symbol (class IsSymbol, SProxy(..), reflectSymbol)
import Data.Tuple (Tuple(..))
import Foreign.Object (Object)
import Foreign.Object as Object
import Payload.ContentType (class HasContentType, getContentType)
import Payload.Docs.JsonSchema (JsonSchema(JsonSchema), JsonSchemaType(..), jsonSchema)
import Payload.Docs.OpenApi (MediaTypeObject, OpenApiSpec, Operation, Param, ParamLocation(..), PathItem, Response, emptyOpenApi, emptyPathItem, mkOperation)
import Payload.Internal.Route (DefaultRouteSpec, Undefined(..))
import Payload.Spec (class IsSymbolList, Route, Tags(..), reflectSymbolList)
import Prim.Row as Row
import Prim.RowList (class RowToList, kind RowList)
import Prim.RowList as RowList
import Prim.Symbol as Symbol
import Type.Equality (class TypeEquals)
import Type.Proxy (Proxy(..))
import Type.RowList (RLProxy(..))

class ToJsonSchema a where
  toJsonSchema :: Proxy a -> JsonSchema

instance toJsonSchemaString :: ToJsonSchema String where
  toJsonSchema _ = jsonSchema (_ { "type" = Just JsonSchemaString })
instance toJsonSchemaNumber :: ToJsonSchema Number where
  toJsonSchema _ = jsonSchema (_ { "type" = Just JsonSchemaNumber })
instance toJsonSchemaInt :: ToJsonSchema Int where
  toJsonSchema _ = jsonSchema (_ { "type" = Just JsonSchemaInteger })
instance toJsonSchemaBoolean :: ToJsonSchema Boolean where
  toJsonSchema _ = jsonSchema (_ { "type" = Just JsonSchemaBoolean })
instance toJsonSchemaArray :: ToJsonSchema a => ToJsonSchema (Array a) where
  toJsonSchema _ = jsonSchema (_ { "type" = Just JsonSchemaArray
                                 , items = Just (toJsonSchema (Proxy :: _ a))})
instance toJsonSchemaList :: ToJsonSchema a => ToJsonSchema (List a) where
  toJsonSchema _ = jsonSchema (_ { "type" = Just JsonSchemaArray
                                 , items = Just (toJsonSchema (Proxy :: _ a))})
instance toJsonSchemaRecord :: ( ToJsonSchemaRowList rl
                               , RowToList a rl
                               ) => ToJsonSchema (Record a) where
  toJsonSchema _ = jsonSchema (_ { "type" = Just JsonSchemaObject
                                 , properties = Just properties
                                 , required = Just required})
    where
      fieldsJsonSchema :: Array FieldJsonSchema
      fieldsJsonSchema = toJsonSchemaRowList (RLProxy :: _ rl)

      properties :: Object JsonSchema
      properties = Object.fromFoldable $ fieldProp <$> fieldsJsonSchema

      fieldProp :: FieldJsonSchema -> Tuple String JsonSchema
      fieldProp {key, schema} = Tuple key schema

      required :: Array String
      required = fieldsJsonSchema
                 # Array.filter _.required
                 # map _.key

class ToJsonSchemaRowList (rl :: RowList) where
  toJsonSchemaRowList :: RLProxy rl -> Array FieldJsonSchema

instance toJsonSchemaRowListNil :: ToJsonSchemaRowList RowList.Nil where
  toJsonSchemaRowList _ = []

else instance toJsonSchemaRowListConsMaybe ::
  ( ToJsonSchema val
  , ToJsonSchemaRowList rest
  , IsSymbol key
  ) => ToJsonSchemaRowList (RowList.Cons key (Maybe val) rest) where
  toJsonSchemaRowList _ = Array.cons this rest
    where
      this :: FieldJsonSchema
      this = { key, required: false, schema }
      
      key :: String
      key = reflectSymbol (SProxy :: _ key)
      
      schema :: JsonSchema
      schema = toJsonSchema (Proxy :: _ val)
      
      rest :: Array FieldJsonSchema
      rest = toJsonSchemaRowList (RLProxy :: _ rest)

else instance toJsonSchemaRowListCons ::
  ( ToJsonSchema val
  , ToJsonSchemaRowList rest
  , IsSymbol key
  ) => ToJsonSchemaRowList (RowList.Cons key val rest) where
  toJsonSchemaRowList _ = Array.cons this rest
    where
      this :: FieldJsonSchema
      this = { key, required: true, schema }
      
      key :: String
      key = reflectSymbol (SProxy :: _ key)
      
      schema :: JsonSchema
      schema = toJsonSchema (Proxy :: _ val)
      
      rest :: Array FieldJsonSchema
      rest = toJsonSchemaRowList (RLProxy :: _ rest)

type FieldJsonSchema =
  { key :: String
  , required :: Boolean
  , schema :: JsonSchema }

class ToJsonSchemaQueryParams query where
  toJsonSchemaQueryParams :: Proxy query -> Array FieldJsonSchema

instance toJsonSchemaQueryParamsUndefined :: ToJsonSchemaQueryParams Undefined where
  toJsonSchemaQueryParams _ = []

instance toJsonSchemaQueryParamsRecord ::
  ( RowToList query queryList
  , ToJsonSchemaRowList queryList
  ) => ToJsonSchemaQueryParams (Record query) where
  toJsonSchemaQueryParams _ = toJsonSchemaRowList (RLProxy :: _ queryList)
