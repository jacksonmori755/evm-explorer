defmodule Explorer.PagingOptions do
  @moduledoc """
  Defines paging options for paging by a stable key such as a timestamp or block
  number and index.
  """

  @type t :: %__MODULE__{
          key: key,
          page_size: page_size,
          page_number: page_number,
          is_pending_tx: is_pending_tx,
          is_index_in_asc_order: is_index_in_asc_order
        }

  @typep key :: any()
  @typep page_size :: non_neg_integer()
  @typep page_number :: pos_integer()
  @typep is_pending_tx :: atom()
  @typep is_index_in_asc_order :: atom()

  defstruct [:key, :page_size, page_number: 1, is_pending_tx: false, is_index_in_asc_order: false]
end
