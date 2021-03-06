require 'spec_helper_unit'
require 'support/factories/users'
require 'helpers/named_maps_helper'

class FakeCartoHttpClientFileToucher
  attr_reader :touched_files

  def initialize
    @touched_files = []
  end

  # Mock needs not url nor Typhoeus options
  def get_file(_, exported_file, _)
    @touched_files << exported_file
    touch(exported_file)
  end

  private

  def random_filename(dir, extension: 'shp')
    "#{dir}/test_#{String.random(12)}.#{extension}".downcase
  end

  def touch_random_filename(dir, extension: 'shp')
    touch(random_filename(dir, extension: extension))
  end

  def touch(path)
    FileUtils.touch(path).first
  end
end

describe Carto::DataExporter do
  include CartoDB::Factories
  include NamedMapsHelper

  describe '#export_tables' do
    let(:user) { create(:carto_user, factory_bot_context: { only_db_setup: true }) }

    # INFO: this needs SQL API configured for testing
    it 'exports a table in requested format' do
      table_name = 'table1'
      table = create_table(name: table_name, user_id: user.id)
      user_table = Carto::UserTable.find_by_table_id(table.get_table_id)
      table.insert_row!(id: 666, description: 'desc', name: 'a row')

      format = 'shp'

      tmp_dir = "/tmp/export_test_#{String.random(15)}"
      FileUtils.mkdir_p tmp_dir

      Carto::Http::Request.any_instance.stubs(:run)
      file = File.new(Carto::DataExporter.new.export_table(user_table, tmp_dir, format))
      file.path.should match(/.#{format}$/)
      file.close
    end
  end
end

describe Carto::VisualizationExport do
  include Carto::ExporterConfig
  include Carto::Factories::Visualizations

  let(:user) { create(:carto_user, factory_bot_context: { only_db_setup: true }) }
  let(:other_user) { create(:carto_user, factory_bot_context: { only_db_setup: true }) }
  let(:base_dir) { ensure_clean_folder('/tmp/exporter_test') }

  describe '#export' do
    # TODO: fix
    xit 'exports a .carto file including the carto.json and the files' do
      map = create(:carto_map, user: user)
      table1 = create(:private_user_table, user: user)
      table2 = create(:private_user_table, user: user)
      layer1 = create(:carto_layer, options: { table_name: table1.name }, maps: [map])
      create(:carto_layer, options: { table_name: table2.name }, maps: [map])

      map, _, _, visualization = create_full_visualization(user.carto_user, map: map, table: table1, data_layer: layer1)

      fake_carto_http_client_toucher = FakeCartoHttpClientFileToucher.new

      exported_file = described_class.new.export(
        visualization,
        user,
        base_dir: base_dir,
        data_exporter: Carto::DataExporter.new(fake_carto_http_client_toucher)
      )

      touched_files = fake_carto_http_client_toucher.touched_files
      CartoDB::Importer2::Unp.new.open(exported_file) do |files|
        files.length.should eq(map.layers.count + 1)
        names = files.map(&:path)
        names.count { |f| f =~ /\.carto\.json$/ }.should eq 1
        names.should include(touched_files[0].split('/').last)
        names.should include(touched_files[1].split('/').last)
      end

      ([exported_file] + touched_files).map { |f| File.delete(f) if File.exists?(f) }
    end

    it 'excludes data not accessible by the user' do
      map = create(:carto_map, user: user.carto_user)

      table1 = create(:private_user_table, user: user.carto_user)

      layer1 = create(:carto_layer, options: { table_name: table1.name }, maps: [map])

      map, table, table_visualization, visualization = create_full_visualization(user.carto_user,
                                                                                 map: map,
                                                                                 table: table1,
                                                                                 data_layer: layer1)

      fake_carto_http_client_toucher = FakeCartoHttpClientFileToucher.new

      exported_file = Carto::VisualizationExport.new.export(
        visualization,
        other_user.carto_user,
        base_dir: base_dir,
        data_exporter: Carto::DataExporter.new(fake_carto_http_client_toucher))

      touched_files = fake_carto_http_client_toucher.touched_files
      CartoDB::Importer2::Unp.new.open(exported_file) do |files|
        files.length.should eq 1 # visualization export
        names = files.map(&:path)
        names.count { |f| f =~ /\.carto\.json$/ }.should eq 1
      end

      ([exported_file] + touched_files).map { |f| File.delete(f) if File.exists?(f) }

      destroy_full_visualization(map, table, table_visualization, visualization)
    end

    # TODO: fix
    xit 'excludes layers and user_tables with user_tables_ids parameter' do
      map = create(:carto_map, user: user.carto_user)

      table1 = create(:private_user_table, user: user.carto_user)
      table2 = create(:private_user_table, user: user.carto_user)

      layer1 = create(:carto_layer, options: { table_name: table1.name }, maps: [map])
      create(:carto_layer, options: { table_name: table2.name }, maps: [map])

      map, table, table_visualization, visualization = create_full_visualization(user.carto_user,
                                                                                 map: map,
                                                                                 table: table1,
                                                                                 data_layer: layer1)

      fake_carto_http_client_toucher = FakeCartoHttpClientFileToucher.new

      exported_file = Carto::VisualizationExport.new.export(
        visualization,
        user.carto_user,
        user_tables_ids: [table1.id],
        base_dir: base_dir,
        data_exporter: Carto::DataExporter.new(fake_carto_http_client_toucher))

      touched_files = fake_carto_http_client_toucher.touched_files
      CartoDB::Importer2::Unp.new.open(exported_file) do |files|
        files.length.should eq (1 + 1) # selected user_table + metadata
        names = files.map(&:path)
        names.count { |f| f =~ /\.carto\.json$/ }.should eq 1
        names.should include(touched_files[0].split('/').last)
        touched_files.length.should eq 1
      end

      ([exported_file] + touched_files).map { |f| File.delete(f) if File.exists?(f) }

      destroy_full_visualization(map, table, table_visualization, visualization)
    end
  end

  describe '#run_export!' do
    # run_export! is called from the job, but the core of the logic is in `#export`, this makes sure its usage
    it 'calls #export' do
      visualization = create(:carto_visualization, user: user.carto_user)
      ve = create(:visualization_export, user: user.carto_user, visualization: visualization)

      fake_path = "/tmp/fakepath"
      touch(fake_path)
      ve.expects(:export).returns(fake_path)
      file_upload_helper_mock = mock
      file_upload_helper_mock.expects(:upload_file_to_storage)

      ve.run_export!(file_upload_helper: file_upload_helper_mock)

      visualization.destroy
      File.delete(fake_path) if File.exists?(fake_path)
    end

    describe 'with S3' do
      before do
        @visualization = create(:carto_visualization, user: user.carto_user)
      end

      let(:test_dir) { '/tmp/exports_test/' }
      let(:fake_path) { "#{test_dir}/fake_export.carto" }

      it 'runs export creating a log trace' do
        ve = Carto::VisualizationExport.new(visualization: @visualization, user: user.carto_user)

        FileUtils.mkdir_p test_dir
        FileUtils.touch(fake_path).first
        ve.expects(:export).returns(fake_path)

        file_upload_helper_mock = mock
        file_upload_helper_mock.expects(:upload_file_to_storage).returns(file_url: fake_path)

        ve.run_export!(file_upload_helper: file_upload_helper_mock)
        ve.reload

        ve.log.should_not be_nil
        ve.destroy
      end
    end
  end
end
